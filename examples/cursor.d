/+ dub.sdl:
    name "cursor-example"
    dependency "deimos-lmdb" path="../"
    targetType "executable"
+/

import deimos.lmdb;
import std.stdio;
import std.conv;
import std.string;
import std.file;

int main()
{
    MDB_env* env;
    MDB_txn* txn;
    MDB_dbi dbi;
    MDB_cursor* cursor;
    MDB_val key, data;
    int rc;

    writeln("LMDB 游标示例");
    writeln("=============");

    rc = mdb_env_create(&env);
    if (rc != 0)
    {
        writefln("错误: 无法创建环境 - %s", fromStringz(mdb_strerror(rc)));
        return 1;
    }

    rc = mdb_env_set_mapsize(env, 1024 * 1024 * 10);
    if (rc != 0)
    {
        writefln("错误: 无法设置mapsize - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    if (!exists("./cursor_testdb"))
    {
        mkdir("./cursor_testdb");
    }

    rc = mdb_env_open(env, "./cursor_testdb", 0, 438);
    if (rc != 0)
    {
        writefln("错误: 无法打开环境 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    rc = mdb_txn_begin(env, null, 0, &txn);
    if (rc != 0)
    {
        writefln("错误: 无法开始事务 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    rc = mdb_dbi_open(txn, null, 0, &dbi);
    if (rc != 0)
    {
        writefln("错误: 无法打开数据库 - %s", fromStringz(mdb_strerror(rc)));
        mdb_txn_abort(txn);
        mdb_env_close(env);
        return 1;
    }

    writeln("\n写入多条数据...");
    string[] keys = ["apple", "banana", "cherry", "date", "elderberry"];
    string[] values = ["苹果", "香蕉", "樱桃", "枣", "接骨木果"];

    for (size_t i = 0; i < keys.length; i++)
    {
        key.mv_size = keys[i].length;
        key.mv_data = cast(void*)keys[i].ptr;
        data.mv_size = values[i].length;
        data.mv_data = cast(void*)values[i].ptr;

        rc = mdb_put(txn, dbi, &key, &data, 0);
        if (rc != 0)
        {
            writefln("错误: 无法写入数据 - %s", fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn);
            mdb_env_close(env);
            return 1;
        }
        writefln("  写入: %s => %s", keys[i], values[i]);
    }

    rc = mdb_txn_commit(txn);
    if (rc != 0)
    {
        writefln("错误: 无法提交事务 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    writeln("\n使用游标遍历所有数据...");
    rc = mdb_txn_begin(env, null, EnvironmentFlags.MDB_RDONLY, &txn);
    if (rc != 0)
    {
        writefln("错误: 无法开始只读事务 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    rc = mdb_cursor_open(txn, dbi, &cursor);
    if (rc != 0)
    {
        writefln("错误: 无法打开游标 - %s", fromStringz(mdb_strerror(rc)));
        mdb_txn_abort(txn);
        mdb_env_close(env);
        return 1;
    }

    writeln("\n正向遍历:");
    int count = 0;
    while ((rc = mdb_cursor_get(cursor, &key, &data, MDB_cursor_op.MDB_NEXT)) == 0)
    {
        string k = cast(string)(fromStringz(cast(const(char)*)key.mv_data)[0 .. key.mv_size]);
        string v = cast(string)(fromStringz(cast(const(char)*)data.mv_data)[0 .. data.mv_size]);
        writefln("  [%d] %s => %s", ++count, k, v);
    }

    writeln("\n反向遍历:");
    count = 0;
    while ((rc = mdb_cursor_get(cursor, &key, &data, MDB_cursor_op.MDB_PREV)) == 0)
    {
        string k = cast(string)(fromStringz(cast(const(char)*)key.mv_data)[0 .. key.mv_size]);
        string v = cast(string)(fromStringz(cast(const(char)*)data.mv_data)[0 .. data.mv_size]);
        writefln("  [%d] %s => %s", ++count, k, v);
    }

    writeln("\n定位到特定键...");
    string searchKey = "cherry";
    key.mv_size = searchKey.length;
    key.mv_data = cast(void*)searchKey.ptr;

    rc = mdb_cursor_get(cursor, &key, &data, MDB_cursor_op.MDB_SET_KEY);
    if (rc == 0)
    {
        string v = cast(string)(fromStringz(cast(const(char)*)data.mv_data)[0 .. data.mv_size]);
        writefln("  找到: %s => %s", searchKey, v);
    }
    else if (rc == ErrorCodes.MDB_NOTFOUND)
    {
        writefln("  未找到键: %s", searchKey);
    }
    else
    {
        writefln("  错误: %s", fromStringz(mdb_strerror(rc)));
    }

    mdb_cursor_close(cursor);
    mdb_txn_abort(txn);

    writeln("\n删除数据示例...");
    rc = mdb_txn_begin(env, null, 0, &txn);
    if (rc != 0)
    {
        writefln("错误: 无法开始事务 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    string delKey = "banana";
    key.mv_size = delKey.length;
    key.mv_data = cast(void*)delKey.ptr;

    rc = mdb_del(txn, dbi, &key, null);
    if (rc == 0)
    {
        writefln("  删除成功: %s", delKey);
    }
    else if (rc == ErrorCodes.MDB_NOTFOUND)
    {
        writefln("  未找到键: %s", delKey);
    }
    else
    {
        writefln("  错误: %s", fromStringz(mdb_strerror(rc)));
    }

    rc = mdb_txn_commit(txn);
    if (rc != 0)
    {
        writefln("错误: 无法提交事务 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    writeln("\n删除后的数据:");
    rc = mdb_txn_begin(env, null, EnvironmentFlags.MDB_RDONLY, &txn);
    if (rc != 0)
    {
        writefln("错误: 无法开始只读事务 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    rc = mdb_cursor_open(txn, dbi, &cursor);
    if (rc != 0)
    {
        writefln("错误: 无法打开游标 - %s", fromStringz(mdb_strerror(rc)));
        mdb_txn_abort(txn);
        mdb_env_close(env);
        return 1;
    }

    count = 0;
    while ((rc = mdb_cursor_get(cursor, &key, &data, MDB_cursor_op.MDB_NEXT)) == 0)
    {
        string k = cast(string)(fromStringz(cast(const(char)*)key.mv_data)[0 .. key.mv_size]);
        string v = cast(string)(fromStringz(cast(const(char)*)data.mv_data)[0 .. data.mv_size]);
        writefln("  [%d] %s => %s", ++count, k, v);
    }

    mdb_cursor_close(cursor);
    mdb_txn_abort(txn);
    mdb_dbi_close(env, dbi);
    mdb_env_close(env);

    writeln("\n游标示例运行完成!");
    return 0;
}
