module deimos.lmdb_oop;

import deimos.lmdb;
import std.conv;
import std.string;
import std.range;
import std.typecons;
import std.traits;

public import deimos.lmdb : ErrorCodes, EnvironmentFlags, DatabaseFlags, MDB_cursor_op;

class LmdbException : Exception
{
    int errorCode;
    
    this(int errorCode, string msg = null, string file = __FILE__, size_t line = __LINE__)
    {
        this.errorCode = errorCode;
        string errorMsg = msg ? msg : fromStringz(mdb_strerror(errorCode)).idup;
        super(errorMsg, file, line);
    }
    
    static void check(int rc, string msg = null, string file = __FILE__, size_t line = __LINE__)
    {
        if (rc != 0)
        {
            throw new LmdbException(rc, msg, file, line);
        }
    }
}

struct Val
{
private:
    MDB_val val;
    
public:
    this(size_t size, void* data)
    {
        val.mv_size = size;
        val.mv_data = data;
    }
    
    this(const void[] data)
    {
        val.mv_size = data.length;
        val.mv_data = cast(void*)data.ptr;
    }
    
    this(string str)
    {
        val.mv_size = str.length;
        val.mv_data = cast(void*)str.ptr;
    }
    
    size_t size() const pure nothrow @nogc @property
    {
        return val.mv_size;
    }
    
    void* data() pure nothrow @nogc @property
    {
        return val.mv_data;
    }
    
    const(void)* data() const pure nothrow @nogc @property
    {
        return val.mv_data;
    }
    
    string asString() const nothrow @nogc
    {
        if (val.mv_data is null || val.mv_size == 0)
            return null;
        return () @trusted { return cast(string)(fromStringz(cast(const(char)*)val.mv_data)[0 .. val.mv_size]); } ();
    }
    
    T[] asArray(T)() const pure nothrow @nogc
    {
        if (val.mv_data is null || val.mv_size == 0)
            return null;
        size_t elemCount = val.mv_size / T.sizeof;
        auto result = new T[elemCount];
        () @trusted {
            import core.stdc.string : memcpy;
            memcpy(result.ptr, val.mv_data, val.mv_size);
        } ();
        return result;
    }
    
    T as(T)() const pure nothrow @nogc
    {
        return *cast(T*)val.mv_data;
    }
    
    MDB_val* ptr() pure nothrow @nogc @property
    {
        return &val;
    }
    
    const(MDB_val)* ptr() const pure nothrow @nogc @property
    {
        return &val;
    }
    
    void[] toArray() pure nothrow @nogc @property
    {
        return val.mv_data[0 .. val.mv_size];
    }
}

class Environment
{
private:
    MDB_env* env;
    bool opened = false;
    
public:
    this()
    {
        LmdbException.check(mdb_env_create(&env), "无法创建环境");
    }
    
    ~this()
    {
        if (opened)
            mdb_env_close(env);
    }
    
    Environment setMapsize(size_t size)
    {
        LmdbException.check(mdb_env_set_mapsize(env, size), "无法设置mapsize");
        return this;
    }
    
    Environment setMaxReaders(uint maxReaders)
    {
        LmdbException.check(mdb_env_set_maxreaders(env, maxReaders), "无法设置最大读取者数量");
        return this;
    }
    
    Environment setMaxDbs(uint maxDbs)
    {
        LmdbException.check(mdb_env_set_maxdbs(env, maxDbs), "无法设置最大数据库数量");
        return this;
    }
    
    Environment open(string path, uint flags = 0, int mode = 438)
    {
        LmdbException.check(mdb_env_open(env, path.toStringz, flags, mode), "无法打开环境");
        opened = true;
        return this;
    }
    
    void sync(bool force = false)
    {
        LmdbException.check(mdb_env_sync(env, force ? 1 : 0), "无法同步环境");
    }
    
    MDB_env* handle() pure nothrow @nogc @property
    {
        return env;
    }
    
    MDB_stat getStat()
    {
        MDB_stat stat;
        LmdbException.check(mdb_env_stat(env, &stat), "无法获取统计信息");
        return stat;
    }
    
    MDB_envinfo getInfo()
    {
        MDB_envinfo info;
        LmdbException.check(mdb_env_info(env, &info), "无法获取环境信息");
        return info;
    }
    
    int getMaxKeySize()
    {
        return mdb_env_get_maxkeysize(env);
    }
    
    void close()
    {
        if (opened)
        {
            mdb_env_close(env);
            opened = false;
        }
    }
}

class Transaction
{
private:
    MDB_txn* txn;
    Environment env;
    bool committed = false;
    bool aborted = false;
    
public:
    this(Environment env, uint flags = 0, Transaction parent = null)
    {
        this.env = env;
        MDB_txn* parentTxn = parent ? parent.txn : null;
        LmdbException.check(mdb_txn_begin(env.handle, parentTxn, flags, &txn), "无法开始事务");
    }
    
    ~this()
    {
        if (txn !is null && !committed && !aborted)
            mdb_txn_abort(txn);
    }
    
    void commit()
    {
        if (committed || aborted)
            throw new LmdbException(ErrorCodes.MDB_BAD_TXN, "事务已结束");
        LmdbException.check(mdb_txn_commit(txn), "无法提交事务");
        committed = true;
    }
    
    void abort()
    {
        if (committed || aborted)
            throw new LmdbException(ErrorCodes.MDB_BAD_TXN, "事务已结束");
        mdb_txn_abort(txn);
        aborted = true;
    }
    
    void reset()
    {
        mdb_txn_reset(txn);
    }
    
    void renew()
    {
        LmdbException.check(mdb_txn_renew(txn), "无法续订事务");
    }
    
    MDB_txn* handle() pure nothrow @nogc @property
    {
        return txn;
    }
    
    Environment environment() pure nothrow @nogc @property
    {
        return env;
    }
    
    size_t id() @property
    {
        return mdb_txn_id(txn);
    }
}

class Database
{
private:
    MDB_dbi dbi;
    Environment env;
    
public:
    this(Transaction txn, string name = null, uint flags = 0)
    {
        this.env = txn.environment;
        const(char)* namePtr = name ? name.toStringz : null;
        LmdbException.check(mdb_dbi_open(txn.handle, namePtr, flags, &dbi), "无法打开数据库");
    }
    
    ~this()
    {
    }
    
    void close()
    {
        mdb_dbi_close(env.handle, dbi);
    }
    
    void drop(bool deleteDb = false)
    {
        auto txn = new Transaction(env, 0);
        scope(exit) txn.commit();
        LmdbException.check(mdb_drop(txn.handle, dbi, deleteDb ? 1 : 0), "无法删除数据库");
    }
    
    MDB_dbi handle() pure nothrow @nogc @property
    {
        return dbi;
    }
    
    /**
     * 泛型写入键值对
     * 
     * 支持类型：
     *   - 字符串：string, const(char)[]
     *   - 基本类型：int, long, double 等
     *   - POD 结构体
     *   - 动态数组：int[], ubyte[] 等
     * 
     * 示例：
     *   db.put(txn, "key", "value");
     *   db.put(txn, "key", 42);
     *   db.put(txn, 123, "value");
     *   db.put(txn, 123, 456);
     */
    void put(K, V)(Transaction txn, in K key, in V value, uint flags = 0)
    {
        auto keyVal = toValKey!K(key);
        auto dataVal = toVal!V(value);
        LmdbException.check(mdb_put(txn.handle, dbi, keyVal.ptr, dataVal.ptr, flags), "无法写入数据");
    }
    
    /**
     * 泛型读取键值
     * 
     * Returns: 是否找到
     * 
     * 示例：
     *   string val;
     *   if (db.get(txn, "key", val)) { ... }
     *   
     *   int num;
     *   if (db.get(txn, "key", num)) { ... }
     */
    bool get(K, V)(Transaction txn, in K key, out V value)
        if (!is(V == interface))
    {
        auto keyVal = toValKey!K(key);
        MDB_val data;
        int rc = mdb_get(txn.handle, dbi, keyVal.ptr, &data);
        if (rc == ErrorCodes.MDB_NOTFOUND)
            return false;
        LmdbException.check(rc, "无法读取数据");
        
        value = fromVal!V(Val(data.mv_size, data.mv_data));
        return true;
    }
    
    /**
     * 泛型删除键
     */
    void del(K)(Transaction txn, in K key)
    {
        auto keyVal = toValKey!K(key);
        int rc = mdb_del(txn.handle, dbi, keyVal.ptr, null);
        if (rc == ErrorCodes.MDB_NOTFOUND)
            return;
        LmdbException.check(rc, "无法删除数据");
    }
    
    /**
     * 泛型查找键值，不存在返回默认值
     */
    V find(K, V)(Transaction txn, in K key, V def)
        if (!is(V == interface))
    {
        V value;
        if (get(txn, key, value))
            return value;
        return def;
    }
    
    /**
     * 检查键是否存在（泛型）
     */
    bool exists(K)(Transaction txn, in K key)
    {
        auto keyVal = toValKey!K(key);
        MDB_val data;
        int rc = mdb_get(txn.handle, dbi, keyVal.ptr, &data);
        return rc == 0;
    }
    
    MDB_stat getStat(Transaction txn)
    {
        MDB_stat stat;
        LmdbException.check(mdb_stat(txn.handle, dbi, &stat), "无法获取统计信息");
        return stat;
    }
    
    size_t count(Transaction txn)
    {
        MDB_stat stat = getStat(txn);
        return stat.ms_entries;
    }
    
private:
    /**
     * 将任意类型转换为 Val（用于 value）
     */
    static Val toVal(T)(in T val)
    {
        static if (is(Unqual!T == Val))
        {
            return cast(Val) val;
        }
        else static if (isSomeString!T)
        {
            return Val(val);
        }
        else static if (isDynamicArray!T)
        {
            import std.range.primitives : ElementEncodingType;
            static if (is(T == ubyte[]) || is(T == const(ubyte)[]) || is(T == void[]) || is(T == const(void)[]))
            {
                return Val(val);
            }
            else
            {
                return Val(val.length * ElementEncodingType!T.sizeof, cast(void*) val.ptr);
            }
        }
        else static if (isPointer!T)
        {
            return Val(T.sizeof, cast(void*) val);
        }
        else
        {
            import std.traits : Unqual;
            static Unqual!T valStorage;
            valStorage = cast(Unqual!T) val;
            return Val(Unqual!T.sizeof, cast(void*) &valStorage);
        }
    }
    
    /**
     * 将任意类型转换为 Val（用于 key）
     * 使用独立的 TLS 缓冲区，避免 put(key, value) 时覆盖
     */
    static Val toValKey(T)(in T val)
    {
        static if (is(Unqual!T == Val))
        {
            return cast(Val) val;
        }
        else static if (isSomeString!T)
        {
            return Val(val);
        }
        else static if (isDynamicArray!T)
        {
            import std.range.primitives : ElementEncodingType;
            static if (is(T == ubyte[]) || is(T == const(ubyte)[]) || is(T == void[]) || is(T == const(void)[]))
            {
                return Val(val);
            }
            else
            {
                return Val(val.length * ElementEncodingType!T.sizeof, cast(void*) val.ptr);
            }
        }
        else static if (isPointer!T)
        {
            return Val(T.sizeof, cast(void*) val);
        }
        else
        {
            import std.traits : Unqual;
            static Unqual!T keyStorage;
            keyStorage = cast(Unqual!T) val;
            return Val(Unqual!T.sizeof, cast(void*) &keyStorage);
        }
    }
    
    /**
     * 从 Val 转换为目标类型
     */
    static V fromVal(V)(Val val)
    {
        static if (is(Unqual!V == Val))
        {
            return val;
        }
        else static if (isSomeString!V)
        {
            return val.asString.idup;
        }
        else static if (isDynamicArray!V && !is(V == class))
        {
            import std.range.primitives : ElementEncodingType;
            static if (is(V == ubyte[]) || is(V == const(ubyte)[]) || is(V == void[]) || is(V == const(void)[]))
            {
                return cast(V) val.toArray;
            }
            else
            {
                alias E = ElementEncodingType!V;
                size_t elemCount = val.size / E.sizeof;
                auto result = new Unqual!E[elemCount];
                const(ubyte)* src = cast(const(ubyte)*) val.data;
                () @trusted { 
                    import core.stdc.string : memcpy;
                    memcpy(result.ptr, src, val.size);
                } ();
                return cast(V) result;
            }
        }
        else
        {
            if (V.sizeof > val.size)
                throw new LmdbException(ErrorCodes.MDB_BAD_VALSIZE, "数据大小不足");
            return val.as!V;
        }
    }
}

class Cursor
{
private:
    MDB_cursor* cursor;
    Transaction txn;
    
public:
    this(Transaction txn, Database db)
    {
        this.txn = txn;
        LmdbException.check(mdb_cursor_open(txn.handle, db.handle, &cursor), "无法打开游标");
    }
    
    ~this()
    {
        if (cursor !is null)
            mdb_cursor_close(cursor);
    }
    
    void close()
    {
        if (cursor !is null)
        {
            mdb_cursor_close(cursor);
            cursor = null;
        }
    }
    
    void renew(Transaction newTxn)
    {
        LmdbException.check(mdb_cursor_renew(newTxn.handle, cursor), "无法续订游标");
        this.txn = newTxn;
    }
    
    /**
     * 泛型游标定位
     * 
     * Returns: 是否找到
     */
    bool get(K, V)(ref K key, ref V value, MDB_cursor_op op)
    {
        auto keyVal = Database.toValKey!K(key);
        MDB_val data;
        int rc = mdb_cursor_get(cursor, keyVal.ptr, &data, op);
        if (rc == ErrorCodes.MDB_NOTFOUND)
            return false;
        LmdbException.check(rc, "游标操作失败");
        value = Database.fromVal!V(Val(data.mv_size, data.mv_data));
        return true;
    }
    
    /**
     * 泛型游标写入
     */
    void put(K, V)(in K key, in V value, uint flags = 0)
    {
        auto keyVal = Database.toValKey!K(key);
        auto dataVal = Database.toVal!V(value);
        LmdbException.check(mdb_cursor_put(cursor, keyVal.ptr, dataVal.ptr, flags), "游标写入失败");
    }
    
    void del(uint flags = 0)
    {
        LmdbException.check(mdb_cursor_del(cursor, flags), "游标删除失败");
    }
    
    size_t count()
    {
        mdb_size_t cnt;
        LmdbException.check(mdb_cursor_count(cursor, &cnt), "无法计数");
        return cnt;
    }
    
    bool first(K, V)(ref K key, ref V value)
    {
        return get(key, value, MDB_cursor_op.MDB_FIRST);
    }
    
    bool last(K, V)(ref K key, ref V value)
    {
        return get(key, value, MDB_cursor_op.MDB_LAST);
    }
    
    bool next(K, V)(ref K key, ref V value)
    {
        return get(key, value, MDB_cursor_op.MDB_NEXT);
    }
    
    bool prev(K, V)(ref K key, ref V value)
    {
        return get(key, value, MDB_cursor_op.MDB_PREV);
    }
    
    bool set(K, V)(ref K key, ref V value)
    {
        return get(key, value, MDB_cursor_op.MDB_SET);
    }
    
    bool setKey(K, V)(ref K key, ref V value)
    {
        return get(key, value, MDB_cursor_op.MDB_SET_KEY);
    }
    
    bool setRange(K, V)(ref K key, ref V value)
    {
        return get(key, value, MDB_cursor_op.MDB_SET_RANGE);
    }
}

struct CursorRange(K, V)
{
private:
    Cursor cursor;
    bool hasMore = true;
    K currentKey;
    V currentData;
    
public:
    this(Cursor cursor)
    {
        this.cursor = cursor;
        hasMore = cursor.first(currentKey, currentData);
    }
    
    @property bool empty() const pure nothrow @nogc
    {
        return !hasMore;
    }
    
    @property ref K front() pure nothrow @nogc
    {
        return currentKey;
    }
    
    void popFront()
    {
        hasMore = cursor.next(currentKey, currentData);
    }
    
    static CursorRange opCall(Cursor cursor)
    {
        return CursorRange(cursor);
    }
}

alias KeyValue(K, V) = Tuple!(K, V);

struct KeyValueRange(K, V)
{
private:
    Cursor cursor;
    bool hasMore = true;
    K currentKey;
    V currentData;
    
public:
    this(Cursor cursor)
    {
        this.cursor = cursor;
        hasMore = cursor.first(currentKey, currentData);
    }
    
    @property bool empty() const pure nothrow @nogc
    {
        return !hasMore;
    }
    
    @property KeyValue!(K, V) front() pure nothrow @nogc
    {
        return tuple(currentKey, currentData);
    }
    
    void popFront()
    {
        hasMore = cursor.next(currentKey, currentData);
    }
    
    static KeyValueRange opCall(Cursor cursor)
    {
        return KeyValueRange(cursor);
    }
}
