/+ dub.sdl:
    name "lmdb-test-shared-simple"
    dependency "deimos-lmdb" path="../"
    targetType "executable"
+/

module examples.test_shared_simple;

import deimos.shared_lmdb;
import std.stdio;
import std.file;
import core.thread;
import core.time : msecs;

void main()
{
    writeln("=== 简单共享 LMDB 客户端测试 ===");
    
    const dir = "./test_simple";
    if (dir.exists && dir.isDir)
        dir.rmdirRecurse;
    dir.mkdir;
    
    const dbPath = dir ~ "/test.db";
    
    {
        scope client = new AutoLmdbClient(dbPath, 10, 1);
        
        writeln("1. 基本写入读取测试");
        assert(client.write("key1", "value1"));
        assert(client.read!string("key1", "") == "value1");
        writeln("  ✓ 写入/读取字符串 OK");
        
        assert(client.write("key2", 123));
        assert(client.read!int("key2", 0) == 123);
        writeln("  ✓ 写入/读取整数 OK");
        
        assert(client.write("key3", 3.14));
        assert(client.read!double("key3", 0.0) == 3.14);
        writeln("  ✓ 写入/读取浮点数 OK");
        
        assert(client.exists("key1"));
        assert(!client.exists("nonexistent"));
        writeln("  ✓ exists() 函数 OK");
        
        assert(client.remove("key1"));
        assert(!client.exists("key1"));
        writeln("  ✓ 删除操作 OK");
        
        assert(client.upsert("upsert_key", "first"));
        assert(client.read!string("upsert_key", "") == "first");
        assert(client.upsert("upsert_key", "second"));
        assert(client.read!string("upsert_key", "") == "second");
        writeln("  ✓ upsert() 函数 OK");
        
        string[] keys = ["batch1", "batch2", "batch3"];
        string[] values = ["val1", "val2", "val3"];
        assert(client.batch(keys, values));
        assert(client.read!string("batch1", "") == "val1");
        assert(client.read!string("batch2", "") == "val2");
        assert(client.read!string("batch3", "") == "val3");
        writeln("  ✓ 批量操作 OK");
        
        client.printStats();
    }
    
    // 重新打开数据库验证持久化
    {
        scope client = new AutoLmdbClient(dbPath, 10, 1);
        
        writeln("\n2. 重新打开验证持久化");
        assert(client.read!int("key2", 0) == 123, "整数持久化");
        assert(client.read!double("key3", 0.0) == 3.14, "浮点数持久化");
        assert(client.read!string("upsert_key", "") == "second", "upsert 持久化");
        assert(client.read!string("batch1", "") == "val1", "批量写入持久化");
        writeln("  ✓ 数据持久化 OK");
    }
    
    // 多客户端实例测试
    {
        writeln("\n3. 多客户端实例测试");
        scope client1 = new AutoLmdbClient(dbPath, 10, 1);
        scope client2 = new AutoLmdbClient(dbPath, 10, 1);
        
        // 客户端1写入
        assert(client1.write("shared_key", "from_client1"));
        
        // 客户端2读取
        assert(client2.read!string("shared_key", "") == "from_client1");
        writeln("  ✓ 多客户端共享数据 OK");
        
        // 客户端2写入
        assert(client2.write("shared_key", "from_client2"));
        
        // 客户端1读取更新后的值
        assert(client1.read!string("shared_key", "") == "from_client2");
        writeln("  ✓ 多客户端并发更新 OK");
    }
    
    // 清理
    writeln("\n4. 清理测试目录");
    import core.memory : GC;
    GC.collect();
    Thread.sleep(100.msecs);
    dir.rmdirRecurse;
    
    writeln("\n=== 所有测试通过 ===");
}