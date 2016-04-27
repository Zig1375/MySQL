import Foundation
import Dispatch

public class Pool {
    private let accessQueue = dispatch_queue_create("SynchronizedPoolAccess", DISPATCH_QUEUE_SERIAL);

    private var config : ConnectionConfig;
    private var pool : [PoolConnection] = [PoolConnection]();
    private var countPool : UInt = 0;
    private let connectionLimit : UInt;

    public init(config : ConnectionConfig, connectionLimit : UInt = 100) {
        self.config = config;
        self.connectionLimit = max(1, connectionLimit);

        let _ = Thread() {
            sleep(5);
            dispatch_async(self.accessQueue) {
                let len = self.pool.count;
                for index in stride(from: len - 1, to: 0, by: -1) {
                    if (!self.pool[index].isLife()) {
                        self.pool.remove(at : index);
                    }
                }
            }
        }
    }

    func getConnection() -> PoolConnection? {
        var conn : PoolConnection?;
        dispatch_sync(self.accessQueue) {
            conn = self.poolConnection();
        }

        return conn;
    }

    private func poolConnection() -> PoolConnection? {
        if (pool.count == 0) {
            if (countPool < connectionLimit) {
                countPool += 1;
                let conn = PoolConnection(config : self.config);
                if let _ = try? conn.connect() {
                    return conn;
                }
            } else {
                // Уперлись в лимит
                return nil;
            }
        }

        let pc = pool.remove(at : 0);

        if (!pc.isLife()) {
            // Pool сдох, выдаем следующий
            countPool -= 1;
            return poolConnection();
        }

        return pc;
    }

    func release(conn : PoolConnection) {
        dispatch_async(self.accessQueue) {
            self.pool.append(conn);
        }
    }
}