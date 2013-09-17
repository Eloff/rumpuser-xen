#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <mini-os/console.h>
#include <mini-os/kernel.h>
#include <mini-os/netfront.h>

#include <stdlib.h>
#include <stdio.h>

/* for dhcp, see below */
#include <rump/netconfig.h>

void lerror(lua_State *L, char *msg) {
  fprintf(stderr, "\nFATAL ERROR:\n  %s: %s\n\n", msg, lua_tostring(L, -1));
  lua_close(L);
  exit(1);
}

int main(void) {
  /* you can create interfaces from Lua, but ljsyscall doesn't have dhcp support yet, its on the TODO list so do here for now */

  /* a real network interface is currently not required */
#if 0
  int rv;

  if ((rv = rump_pub_netconfig_ifcreate("xenif0")) != 0) {
    printf("creating xenif0 failed: %d\n", rv);
    return 1;
  }

  /*
   * Configure the interface using DHCP.  DHCP support is a bit
   * flimsy, so if this doesn't work properly, you can also use
   * the manual interface configuration options.
   */
  if ((rv = rump_pub_netconfig_dhcp_ipv4_oneshot("xenif0")) != 0) {
    printf("getting IP for xenif0 via DHCP failed: %d\n", rv);
    return 1;
  }
#endif

  lua_State *L;

  L = luaL_newstate();
  if (!L) {
    fprintf(stderr, "\nFATAL ERROR:\n  %s\n\n", "Lua state failed to create");
    return 0;
  }
  luaL_openlibs(L);
  if (luaL_loadstring(L, "require \"test.test\"")) {
	printk("loadstring failed\n");
	lerror(L, "luaL_loadstring() failed");
  }
  if (lua_pcall(L, 0, 0, 0)) {
	lerror(L, "lua_pcall() failed");
  }
  lua_close(L);
  return 0;
}

int
app_main(start_info_t *si)
{
  main();
  return 0;
}


