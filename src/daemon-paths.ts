// see DP.SC.034, DP.IWE.005 — path resolution extracted from daemon.ts for unit testing
// (daemon.ts has module-load side effects: starts a net.Server, writes files — can't
// import it directly in a unit test without those side effects firing).

import path from "node:path";

export interface DaemonPaths {
  socketPath: string;
  pidPath: string;
}

// PID_PATH must live next to the actual socket, not a hardcoded homedir — otherwise
// two daemons started with different IWE_GATEWAY_SOCKET values race on one pid file
// (github.com/TserenTserenov/iwe-local-gateway/issues/1).
export function resolveDaemonPaths(socketEnv: string | undefined, homedir: string): DaemonPaths {
  const socketPath = socketEnv || path.join(homedir, ".iwe", "gateway.sock");
  const pidPath = path.join(path.dirname(socketPath), "gateway.pid");
  return { socketPath, pidPath };
}
