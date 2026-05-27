module deimos.shared_lmdb;


import deimos.lmdb_oop;
import core.thread;
import core.time : msecs;
import std.conv : to;
import std.random : uniform;
import std.stdio;

/**
 * 多副本自动化 LMDB 客户端
 * 所有实例使用相同代码，写入冲突自动重试
 */
class AutoLmdbClient
{
private:
    string dbPath;
    Environment env;
    Database db;
    bool hasWriteAccess = true;  // 假设都有写权限
    
public:
    /**
     * 构造函数 - 所有实例相同配置
     * 
     * @param path 数据库路径（所有实例使用相同路径）
     * @param maxReaders 最大读者数（默认256）
     * @param mapsizeMB 映射大小MB（默认100MB）
     */
    this(string path, int maxReaders = 256, int mapsizeMB = 100)
    {
        dbPath = path;
        
        env = new Environment()
            .setMapsize(mapsizeMB * 1024 * 1024)
            .setMaxReaders(maxReaders)
            .setMaxDbs(20);
        
        env.open(dbPath, EnvironmentFlags.MDB_NOSUBDIR, 438);
        
        // 打开默认数据库（读写模式）
        auto txn = new Transaction(env);
        db = new Database(txn, null, DatabaseFlags.MDB_CREATE);
        txn.commit();
    }
    
    ~this()
    {
        env.close();
    }
    
    /**
     * 自动化读取（所有实例通用）
     */
    T read(T)(string key, T defaultValue)
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        T value;
        if (db.get(txn, key, value))
            return value;
        return defaultValue;
    }
    
    /**
     * 检查键是否存在
     */
    bool exists(string key)
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        return db.exists(txn, key);
    }
    
    /**
     * 自动化写入 - 冲突自动重试
     * 
     * 最多重试5次，随机退避避免冲突
     */
    bool write(T)(string key, T value, int maxRetries = 5)
    {
        if (!hasWriteAccess)
            return false;  // 理论上不会进入，保留判断
        
        for (int retry = 0; retry < maxRetries; retry++)
        {
            try
            {
                auto txn = new Transaction(env);
                db.put(txn, key, value);
                txn.commit();
                return true;
            }
            catch (LmdbException e)
            {
                if (e.errorCode == ErrorCodes.MDB_BAD_TXN)
                {
                    // 写冲突，随机退避后重试
                    int delay = 10 + uniform(0, 30);  // 10-40ms 随机延迟
                    Thread.sleep(delay.msecs);
                    continue;
                }
                else if (e.errorCode == ErrorCodes.MDB_MAP_FULL)
                {
                    // 自动扩展映射大小（翻倍）
                    auto info = env.getInfo();
                    size_t newSize = info.me_mapsize * 2;
                    env.setMapsize(newSize);
                    continue;
                }
                else
                {
                    // 其他错误（权限、磁盘满等）抛出
                    throw e;
                }
            }
        }
        
        // 重试失败，降级为只读模式
        hasWriteAccess = false;
        return false;
    }
    
    /**
     * 自动更新或插入（简化版 UPSERT）
     */
    bool upsert(T)(string key, T value)
    {
        return write(key, value);
    }
    
    /**
     * 删除键
     */
    bool remove(string key)
    {
        for (int retry = 0; retry < 3; retry++)
        {
            try
            {
                auto txn = new Transaction(env);
                db.del(txn, key);
                txn.commit();
                return true;
            }
            catch (LmdbException e)
            {
                if (e.errorCode == ErrorCodes.MDB_NOTFOUND)
                    return true;  // 键不存在也视为成功
                
                if (e.errorCode == ErrorCodes.MDB_BAD_TXN)
                {
                    Thread.sleep(20.msecs);
                    continue;
                }
                throw e;
            }
        }
        return false;
    }
    
    /**
     * 批量操作（事务性） - 字符串版本
     */
    bool batch(string[] keys, string[] values)
    {
        for (int retry = 0; retry < 3; retry++)
        {
            try
            {
                auto txn = new Transaction(env);
                foreach (i, key; keys)
                {
                    db.put(txn, key, values[i]);
                }
                txn.commit();
                return true;
            }
            catch (LmdbException e)
            {
                if (e.errorCode == ErrorCodes.MDB_BAD_TXN)
                {
                    Thread.sleep(30.msecs);
                    continue;
                }
                throw e;
            }
        }
        return false;
    }
    
    /**
     * 批量操作（事务性） - 整数版本
     */
    bool batch(string[] keys, int[] values)
    {
        for (int retry = 0; retry < 3; retry++)
        {
            try
            {
                auto txn = new Transaction(env);
                foreach (i, key; keys)
                {
                    db.put(txn, key, values[i]);
                }
                txn.commit();
                return true;
            }
            catch (LmdbException e)
            {
                if (e.errorCode == ErrorCodes.MDB_BAD_TXN)
                {
                    Thread.sleep(30.msecs);
                    continue;
                }
                throw e;
            }
        }
        return false;
    }
    
    /**
     * 获取数据库统计信息
     */
    void printStats()
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        auto stat = db.getStat(txn);
        writeln("数据库统计:");
        writeln("  条目数: ", stat.ms_entries);
        writeln("  深度: ", stat.ms_depth);
    }
}