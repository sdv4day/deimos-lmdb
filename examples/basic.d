/+ dub.sdl:
    name "basic-example"
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
    MDB_val key, data;
    int rc;

    writeln("LMDB D语言绑定示例");
    writeln("===================");

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

    if (!exists("./testdb"))
    {
        mkdir("./testdb");
    }

    rc = mdb_env_open(env, "./testdb", 0, 438);
    if (rc != 0)
    {
        writefln("错误: 无法打开环境 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    writeln("环境创建成功");

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

    writeln("数据库打开成功");

    string testKey = "test_key";
    string testData = "Hello, LMDB from D!";

    key.mv_size = testKey.length;
    key.mv_data = cast(void*)testKey.ptr;

    data.mv_size = testData.length;
    data.mv_data = cast(void*)testData.ptr;

    rc = mdb_put(txn, dbi, &key, &data, 0);
    if (rc != 0)
    {
        writefln("错误: 无法写入数据 - %s", fromStringz(mdb_strerror(rc)));
        mdb_txn_abort(txn);
        mdb_env_close(env);
        return 1;
    }

    writeln("写入数据成功: ", testKey, " => ", testData);

    MDB_val readData;
    rc = mdb_get(txn, dbi, &key, &readData);
    if (rc != 0)
    {
        writefln("错误: 无法读取数据 - %s", fromStringz(mdb_strerror(rc)));
        mdb_txn_abort(txn);
        mdb_env_close(env);
        return 1;
    }

    string readStr = cast(string)(fromStringz(cast(const(char)*)readData.mv_data)[0 .. readData.mv_size]);
    writeln("读取数据成功: ", testKey, " => ", readStr);

    rc = mdb_txn_commit(txn);
    if (rc != 0)
    {
        writefln("错误: 无法提交事务 - %s", fromStringz(mdb_strerror(rc)));
        mdb_env_close(env);
        return 1;
    }

    writeln("事务提交成功");

    mdb_dbi_close(env, dbi);
    mdb_env_close(env);

    writeln("环境关闭成功");
    writeln("示例运行完成!");

    return 0;
}
