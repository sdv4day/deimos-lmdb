/+ dub.sdl:
    name "lmdb-test"
    dependency "deimos-lmdb" path="../"
    targetType "executable"
+/

module examples.test_lmdb;

import deimos.lmdb_oop;
import std.stdio;
import std.file;
import std.conv;
import core.thread;
import core.memory : GC;

struct UserInfo
{
    int id;
    int age;
}

shared bool allPassed = true;

void check(bool cond, string msg)
{
    if (!cond)
    {
        writeln("  FAIL: ", msg);
        allPassed = false;
    }
    else
    {
        writeln("  PASS: ", msg);
    }
}

void testPersistence()
{
    writeln("\n=== 实体文件测试：写入→关闭→重新打开→验证 ===");
    
    const dir = "./test_persistence";
    if (dir.exists && dir.isDir)
        dir.rmdirRecurse;
    dir.mkdir;
    
    Database db;
    
    // 阶段1：写入数据并关闭
    {
        auto env = new Environment()
            .setMapsize(1024 * 1024)
            .setMaxDbs(2);
        env.open(dir);
        
        auto txn = new Transaction(env);
        db = new Database(txn, null, DatabaseFlags.MDB_CREATE);
        
        db.put(txn, "name", "张三");
        db.put(txn, "age", 25);
        db.put(txn, "score", 95.5);
        db.put(txn, 1, "第一条");
        db.put(txn, 2, "第二条");
        
        UserInfo ui = UserInfo(100, 30);
        db.put(txn, "userinfo", ui);
        
        int[] arr = [10, 20, 30, 40, 50];
        db.put(txn, "numbers", arr);
        
        txn.commit();
        env.close();
    }
    
    // 阶段2：重新打开环境，验证数据持久化
    {
        auto env = new Environment()
            .setMapsize(1024 * 1024)
            .setMaxDbs(2);
        env.open(dir);
        
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        
        auto db2 = new Database(txn, null);
        
        string name;
        check(db2.get(txn, "name", name) && name == "张三", "字符串持久化");
        
        int age;
        check(db2.get(txn, "age", age) && age == 25, "整数持久化");
        
        double score;
        check(db2.get(txn, "score", score) && score == 95.5, "浮点数持久化");
        
        string v1, v2;
        check(db2.get(txn, 1, v1) && v1 == "第一条", "整数键持久化(1)");
        check(db2.get(txn, 2, v2) && v2 == "第二条", "整数键持久化(2)");
        
        UserInfo ui;
        check(db2.get(txn, "userinfo", ui) && ui.id == 100 && ui.age == 30, "结构体持久化");
        
        int[] arr;
        check(db2.get(txn, "numbers", arr) && arr == [10, 20, 30, 40, 50], "数组持久化");
        
        check(db2.count(txn) == 7, "条目数持久化 (7)");
        
        txn.abort();
        env.close();
    }
    
    GC.collect();
    dir.rmdirRecurse;
}

void testReadVerify()
{
    writeln("\n=== 读取验证：put 后立即 get 验证数据一致性 ===");
    
    const dir = "./test_readverify";
    if (dir.exists && dir.isDir)
        dir.rmdirRecurse;
    dir.mkdir;
    
    auto env = new Environment()
        .setMapsize(1024 * 1024)
        .setMaxDbs(2);
    env.open(dir);
    
    Database db;
    
    // 字符串读写一致性
    {
        auto txn = new Transaction(env);
        db = new Database(txn, null, DatabaseFlags.MDB_CREATE);
        
        db.put(txn, "k1", "hello");
        db.put(txn, "k2", "世界");
        db.put(txn, "k3", "");           // 空字符串
        db.put(txn, "k4", "a");          // 单字符
        db.put(txn, "k5", "中文测试123!@#");  // 混合
        
        string v;
        check(db.get(txn, "k1", v) && v == "hello", "字符串读写: hello");
        check(db.get(txn, "k2", v) && v == "世界", "字符串读写: 世界");
        check(db.get(txn, "k3", v) && v == "", "字符串读写: 空");
        check(db.get(txn, "k4", v) && v == "a", "字符串读写: 单字符");
        check(db.get(txn, "k5", v) && v == "中文测试123!@#", "字符串读写: 混合");
        
        txn.commit();
    }
    
    // 整数读写一致性
    {
        auto txn = new Transaction(env);
        db.put(txn, "int0", 0);
        db.put(txn, "int1", 1);
        db.put(txn, "intMax", int.max);
        db.put(txn, "intMin", int.min);
        db.put(txn, "longVal", 0x7FFF_FFFF_FFFF_FFFFL);
        
        int vi;
        check(db.get(txn, "int0", vi) && vi == 0, "整数读写: 0");
        check(db.get(txn, "int1", vi) && vi == 1, "整数读写: 1");
        check(db.get(txn, "intMax", vi) && vi == int.max, "整数读写: max");
        check(db.get(txn, "intMin", vi) && vi == int.min, "整数读写: min");
        
        long vl;
        check(db.get(txn, "longVal", vl) && vl == 0x7FFF_FFFF_FFFF_FFFFL, "long读写");
        
        txn.commit();
    }
    
    // 浮点读写一致性
    {
        auto txn = new Transaction(env);
        db.put(txn, "d0", 0.0);
        db.put(txn, "d1", 1.0);
        db.put(txn, "dPi", 3.14159265358979);
        db.put(txn, "dNeg", -100.5);
        db.put(txn, "dSmall", 1e-10);
        
        double vd;
        check(db.get(txn, "d0", vd) && vd == 0.0, "浮点读写: 0.0");
        check(db.get(txn, "d1", vd) && vd == 1.0, "浮点读写: 1.0");
        check(db.get(txn, "dPi", vd) && vd == 3.14159265358979, "浮点读写: pi");
        check(db.get(txn, "dNeg", vd) && vd == -100.5, "浮点读写: 负数");
        check(db.get(txn, "dSmall", vd) && vd == 1e-10, "浮点读写: 小数");
        
        txn.commit();
    }
    
    // bool 读写一致性
    {
        auto txn = new Transaction(env);
        db.put(txn, "bTrue", true);
        db.put(txn, "bFalse", false);
        
        bool vb;
        check(db.get(txn, "bTrue", vb) && vb == true, "bool读写: true");
        check(db.get(txn, "bFalse", vb) && vb == false, "bool读写: false");
        
        txn.commit();
    }
    
    // 整数键读写一致性
    {
        auto txn = new Transaction(env);
        db.put(txn, 0, "zero");
        db.put(txn, 100, "hundred");
        db.put(txn, -1, "neg_one");
        
        string vs;
        check(db.get(txn, 0, vs) && vs == "zero", "整数键读写: 0");
        check(db.get(txn, 100, vs) && vs == "hundred", "整数键读写: 100");
        check(db.get(txn, -1, vs) && vs == "neg_one", "整数键读写: -1");
        
        txn.commit();
    }
    
    // 结构体读写一致性
    {
        auto txn = new Transaction(env);
        
        UserInfo u1 = UserInfo(1, 20);
        UserInfo u2 = UserInfo(999, 88);
        db.put(txn, "u1", u1);
        db.put(txn, "u2", u2);
        
        UserInfo vr;
        check(db.get(txn, "u1", vr) && vr.id == 1 && vr.age == 20, "结构体读写: u1");
        check(db.get(txn, "u2", vr) && vr.id == 999 && vr.age == 88, "结构体读写: u2");
        
        txn.commit();
    }
    
    // 数组读写一致性
    {
        auto txn = new Transaction(env);
        
        int[] empty = [];
        int[] single = [42];
        int[] multi = [1, 2, 3, 4, 5];
        long[] longs = [100L, 200L, 300L];
        
        db.put(txn, "arrEmpty", empty);
        db.put(txn, "arrSingle", single);
        db.put(txn, "arrMulti", multi);
        db.put(txn, "arrLongs", longs);
        
        int[] vi;
        check(db.get(txn, "arrSingle", vi) && vi == [42], "数组读写: single");
        check(db.get(txn, "arrMulti", vi) && vi == [1, 2, 3, 4, 5], "数组读写: multi");
        
        long[] vl;
        check(db.get(txn, "arrLongs", vl) && vl == [100L, 200L, 300L], "数组读写: longs");
        
        txn.commit();
    }
    
    // exists / find 验证
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        
        check(db.exists(txn, "k1"), "exists: 存在的键");
        check(!db.exists(txn, "nonexistent"), "exists: 不存在的键");
        check(db.exists(txn, 100), "exists: 整数键存在");
        check(!db.exists(txn, 9999), "exists: 整数键不存在");
        
        check(db.find(txn, "int1", -1) == 1, "find: 存在返回值");
        check(db.find(txn, "missing", "默认") == "默认", "find: 不存在返回默认");
        
        txn.abort();
    }
    
    // 覆盖写入验证
    {
        auto txn = new Transaction(env);
        db.put(txn, "overwrite", "v1");
        string vs;
        check(db.get(txn, "overwrite", vs) && vs == "v1", "覆盖写入: 初始值");
        
        db.put(txn, "overwrite", "v2");
        check(db.get(txn, "overwrite", vs) && vs == "v2", "覆盖写入: 新值");
        
        db.put(txn, "overwrite", 123);
        int vi;
        check(db.get(txn, "overwrite", vi) && vi == 123, "覆盖写入: 类型变更");
        
        txn.commit();
    }
    
    // 删除验证
    {
        auto txn = new Transaction(env);
        db.put(txn, "delKey", "toBeDeleted");
        check(db.exists(txn, "delKey"), "删除前存在");
        db.del(txn, "delKey");
        check(!db.exists(txn, "delKey"), "删除后不存在");
        txn.commit();
    }
    
    env.close();
    GC.collect();
    dir.rmdirRecurse;
}

void testMultiThread()
{
    writeln("\n=== 多线程测试：并发读 ===");
    
    const dir = "./test_multithread";
    if (dir.exists && dir.isDir)
        dir.rmdirRecurse;
    dir.mkdir;
    
    auto env = new Environment()
        .setMapsize(1024 * 1024 * 4)
        .setMaxReaders(8);
    env.open(dir);
    
    Database db;
    
    // 先写入数据
    {
        auto txn = new Transaction(env);
        db = new Database(txn, null, DatabaseFlags.MDB_CREATE);
        
        foreach (i; 0 .. 100)
        {
            db.put(txn, "key_" ~ i.to!string, "value_" ~ i.to!string);
            db.put(txn, "int_" ~ i.to!string, i);
        }
        
        txn.commit();
    }
    
    // 多线程并发读
    {
        import std.algorithm : min;
        
        __gshared int[4] readCounts = [0, 0, 0, 0];
        __gshared bool[4] readOk = [true, true, true, true];
        readCounts[] = 0;
        readOk[] = true;
        
        void reader(int threadId)
        {
            int localCount = 0;
            bool localOk = true;
            
            try
            {
                auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
                
                foreach (i; 0 .. 100)
                {
                    string key = "key_" ~ i.to!string;
                    string expected = "value_" ~ i.to!string;
                    
                    string val;
                    if (db.get(txn, key, val))
                    {
                        localCount++;
                        if (val != expected)
                            localOk = false;
                    }
                    else
                    {
                        localOk = false;
                    }
                }
                
                foreach (i; 0 .. 100)
                {
                    string key = "int_" ~ i.to!string;
                    int val;
                    if (db.get(txn, key, val))
                    {
                        if (val != i)
                            localOk = false;
                    }
                    else
                    {
                        localOk = false;
                    }
                }
                
                txn.abort();
            }
            catch (Throwable)
            {
                localOk = false;
            }
            
            readCounts[threadId] = localCount;
            readOk[threadId] = localOk;
        }
        
        Thread[4] threads;
        void delegate()[4] readers;
        foreach (i; 0 .. 4)
        {
            readers[i] = (int tid) { return { reader(tid); }; }(i);
            threads[i] = new Thread(readers[i]);
            threads[i].start();
        }
        foreach (i; 0 .. 4)
        {
            threads[i].join();
        }
        
        foreach (i; 0 .. 4)
        {
            check(readOk[i], "线程" ~ i.to!string ~ " 读取正确");
            check(readCounts[i] == 100, "线程" ~ i.to!string ~ " 读取数量=100");
        }
    }
    
    // 单写多读场景
    writeln("\n--- 单写多读场景 ---");
    {
        __gshared bool writerDone = false;
        __gshared bool[3] readerDone = [false, false, false];
        __gshared bool[3] readerOk = [true, true, true];
        __gshared int[3] readerVersions = [0, 0, 0];
        writerDone = false;
        readerDone[] = false;
        readerOk[] = true;
        readerVersions[] = 0;
        
        void writer()
        {
            try
            {
                foreach (round; 0 .. 10)
                {
                    auto txn = new Transaction(env);
                    db.put(txn, "round", round);
                    db.put(txn, "data", "round_" ~ round.to!string);
                    txn.commit();
                    Thread.sleep(10.msecs);
                }
            }
            catch (Throwable) { }
            writerDone = true;
        }
        
        void reader(int id)
        {
            int maxRound = -1;
            bool localOk = true;
            
            try
            {
                while (!writerDone)
                {
                    auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
                    
                    int round;
                    if (db.get(txn, "round", round))
                    {
                        if (round > maxRound)
                            maxRound = round;
                        
                        string data;
                        if (db.get(txn, "data", data))
                        {
                            string expected = "round_" ~ round.to!string;
                            if (data != expected)
                                localOk = false;
                        }
                    }
                    
                    txn.abort();
                    Thread.sleep(5.msecs);
                }
                
                // 最终读一次确认
                auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
                int round;
                if (db.get(txn, "round", round))
                {
                    if (round > maxRound)
                        maxRound = round;
                    
                    string data;
                    if (db.get(txn, "data", data))
                    {
                        if (data != "round_" ~ round.to!string)
                            localOk = false;
                    }
                }
                txn.abort();
            }
            catch (Throwable)
            {
                localOk = false;
            }
            
            readerDone[id] = true;
            readerOk[id] = localOk;
            readerVersions[id] = maxRound;
        }
        
        auto writeThread = new Thread(&writer);
        writeThread.start();
        
        Thread.sleep(20.msecs);
        
        Thread[3] readThreads;
        void delegate()[3] readDelegates;
        foreach (i; 0 .. 3)
        {
            readDelegates[i] = (int tid) { return { reader(tid); }; }(i);
            readThreads[i] = new Thread(readDelegates[i]);
            readThreads[i].start();
        }
        
        writeThread.join();
        foreach (i; 0 .. 3)
            readThreads[i].join();
        
        check(writerDone, "写入线程完成");
        foreach (i; 0 .. 3)
        {
            check(readerDone[i], "读取线程" ~ i.to!string ~ " 完成");
            check(readerOk[i], "读取线程" ~ i.to!string ~ " 数据一致");
            check(readerVersions[i] >= 0, "读取线程" ~ i.to!string ~ " 观察到写入 (ver=" ~ readerVersions[i].to!string ~ ")");
        }
        
        // 验证最终数据
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        
        int round;
        check(db.get(txn, "round", round) && round == 9, "最终 round=9");
        
        string data;
        check(db.get(txn, "data", data) && data == "round_9", "最终 data=round_9");
        
        txn.abort();
    }
    
    env.close();
    GC.collect();
    dir.rmdirRecurse;
}

void main()
{
    writeln("LMDB 实体测试套件");
    writeln("==================");
    
    testPersistence();
    testReadVerify();
    testMultiThread();
    
    writeln("\n==================");
    if (allPassed)
        writeln("全部测试通过!");
    else
        writeln("存在失败测试!");
}
