import { describe, it, expect } from "vitest";
import path from "node:path";
import { resolveDaemonPaths } from "../src/daemon-paths.js";

const HOMEDIR = "/Users/testuser";

describe("resolveDaemonPaths", () => {
  it("defaults to homedir when IWE_GATEWAY_SOCKET is unset", () => {
    const r = resolveDaemonPaths(undefined, HOMEDIR);
    expect(r.socketPath).toBe(path.join(HOMEDIR, ".iwe", "gateway.sock"));
    expect(r.pidPath).toBe(path.join(HOMEDIR, ".iwe", "gateway.pid"));
  });

  it("puts the pid file next to a flat custom socket path", () => {
    const r = resolveDaemonPaths("/tmp/foo.sock", HOMEDIR);
    expect(r.socketPath).toBe("/tmp/foo.sock");
    expect(r.pidPath).toBe("/tmp/gateway.pid");
  });

  it("puts the pid file next to a nested custom socket path", () => {
    const r = resolveDaemonPaths("/tmp/nested/dir/gateway.sock", HOMEDIR);
    expect(r.socketPath).toBe("/tmp/nested/dir/gateway.sock");
    expect(r.pidPath).toBe("/tmp/nested/dir/gateway.pid");
  });

  it("two daemons with different custom sockets never collide on one pid file", () => {
    const a = resolveDaemonPaths("/tmp/workspace-a/gateway.sock", HOMEDIR);
    const b = resolveDaemonPaths("/tmp/workspace-b/gateway.sock", HOMEDIR);
    expect(a.pidPath).not.toBe(b.pidPath);
  });

  it("treats an empty-string IWE_GATEWAY_SOCKET as unset (falls back to homedir)", () => {
    const r = resolveDaemonPaths("", HOMEDIR);
    expect(r.socketPath).toBe(path.join(HOMEDIR, ".iwe", "gateway.sock"));
    expect(r.pidPath).toBe(path.join(HOMEDIR, ".iwe", "gateway.pid"));
  });
});
