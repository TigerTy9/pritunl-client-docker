# Dockerized pritunl-client

This is a customized, dockerized version of the **Pritunl Client**. It is built specifically to support headless environments (like TrueNAS SCALE) where interactive PIN/MFA entry is not possible.

**Current Version:** [1.3.4566.62](https://github.com/pritunl/pritunl-client-electron/releases/tag/1.3.4566.62)

## Usage

To run this container, set the following environment variables in your TrueNAS Custom App settings or Docker Compose file.

| Variable | Description |
| :--- | :--- |
| `PRITUNL_PROFILE` | Your `pritunl://` profile URI link. |
| `USE_WIREGUARD` | Set to `true` to force WireGuard mode. Defaults to OpenVPN. |

### Required Container Permissions
Because WireGuard operates at the kernel level, the container must have the following host-level permissions to function:
* **Host Networking:** Enabled
* **Privileged Mode:** Enabled
* **Capabilities:** `NET_ADMIN`, `SYS_MODULE`

---

## Headless Authentication (The PIN Bypass)

If your Pritunl server enforces a PIN or MFA, the headless client will fail with an `authentication deferred` error. To fix this for a "Machine User" that cannot provide interactive input, you must manually override the security policy in the Pritunl Server database.

### MongoDB Configuration Update
Run these commands on your **Pritunl Server** host to allow the client to connect using certificate-only authentication:

1. **Enter the MongoDB Shell:**
   ```bash
   sudo mongosh pritunl
   ```

2. **Update the User Profile:**
   Replace `"TrueNAS"` with the specific name of your VPN user.
   ```javascript
   db.users.update(
     { name: "TrueNAS" },
     { 
       $set: { 
         "auth_type": "none",
         "bypass_secondary": true,
         "pin": null,
         "pin_set": false
       } 
     }
   )
   ```

3. **Restart the Pritunl Service:**
   ```bash
   sudo systemctl restart pritunl
   ```

---

## Troubleshooting: Zombie Interfaces

If the container crashes or is updated while a WireGuard tunnel is active, the `wg0` interface may remain "Up" in the host kernel even after the container is gone. This will cause the App status to show as **Offline** or fail to redeploy due to an IP/interface conflict.

### How to clear a stuck interface
Run the following commands in the TrueNAS shell to manually tear down the zombie interface:

1. **Check if the interface exists:**
   ```bash
   ip a | grep wg0
   ```

2. **Delete the interface:**
   ```bash
   sudo ip link delete wg0
   ```

3. **Verify it is gone:**
   Run `ip a` again. Once the interface is removed, the TrueNAS App should be able to transition back to a **Deploying** or **Active** state.

---

## Improvements and Dependencies

This version includes critical networking packages that are missing from the base client image, which are required for WireGuard support:

* **wireguard-tools**: Required for generating encryption keys and managing interfaces.
* **iproute2**: Provides the `ip` command used by `wg-quick`.
* **openresolv**: Provides the `resolvconf` command for DNS management.
* **procps**: Provides the `sysctl` command needed for setting kernel routing marks.

The startup script has been updated to use the `-m wg` flag when `USE_WIREGUARD` is enabled, ensuring the client properly initializes the WireGuard protocol.
