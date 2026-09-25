#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <wayland-client.h>

#include "security-context-v1-client-protocol.h"

static struct wp_security_context_manager_v1 *manager;

static void global(void *data, struct wl_registry *registry, uint32_t name,
		   const char *interface, uint32_t version)
{
	(void)data;
	(void)version;
	if (!strcmp(interface, wp_security_context_manager_v1_interface.name))
		manager = wl_registry_bind(registry, name,
					   &wp_security_context_manager_v1_interface, 1);
}

static void global_remove(void *data, struct wl_registry *registry, uint32_t name)
{
	(void)data;
	(void)registry;
	(void)name;
}

static const struct wl_registry_listener registry_listener = {
	.global = global,
	.global_remove = global_remove,
};

static void die(const char *what)
{
	fprintf(stderr, "wl-sandbox: %s: %s\n", what, strerror(errno));
	exit(1);
}

static struct wl_display *connect_compositor(void)
{
	struct wl_display *display;

	if (!(display = wl_display_connect(NULL)))
		die("cannot connect to the compositor");
	wl_registry_add_listener(wl_display_get_registry(display), &registry_listener, NULL);
	if (wl_display_roundtrip(display) < 0)
		die("cannot talk to the compositor");
	return display;
}

static int usage(void)
{
	fprintf(stderr, "usage: wl-sandbox --probe\n"
			"       wl-sandbox APP_ID SOCKET -- COMMAND [ARGS...]\n");
	return 2;
}

int main(int argc, char *argv[])
{
	struct wl_display *display;
	struct wp_security_context_v1 *context;
	struct sockaddr_un addr = { .sun_family = AF_UNIX };
	int listen_fd, sync_fds[2];

	if (argc == 2 && !strcmp(argv[1], "--probe")) {
		display = connect_compositor();
		wl_display_disconnect(display);
		return manager ? 0 : 1;
	}
	if (argc < 5 || strcmp(argv[3], "--") || !*argv[1] || argv[2][0] != '/')
		return usage();
	if (strlen(argv[2]) >= sizeof(addr.sun_path)) {
		errno = ENAMETOOLONG;
		die(argv[2]);
	}
	strcpy(addr.sun_path, argv[2]);

	display = connect_compositor();
	if (!manager) {
		errno = ENOTSUP;
		die("wp_security_context_manager_v1");
	}

	if (unlink(addr.sun_path) < 0 && errno != ENOENT)
		die(addr.sun_path);
	if ((listen_fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0)) < 0 ||
	    bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0 ||
	    listen(listen_fd, SOMAXCONN) < 0)
		die(addr.sun_path);
	if (pipe2(sync_fds, O_CLOEXEC) < 0)
		die("pipe");

	context = wp_security_context_manager_v1_create_listener(manager, listen_fd, sync_fds[0]);
	wp_security_context_v1_set_sandbox_engine(context, "org.dotfiles.dbus-filter");
	wp_security_context_v1_set_app_id(context, argv[1]);
	wp_security_context_v1_commit(context);
	wp_security_context_v1_destroy(context);
	if (wl_display_roundtrip(display) < 0)
		die("the compositor refused the security context");
	wl_display_disconnect(display);
	close(listen_fd);
	close(sync_fds[0]);

	if (fcntl(sync_fds[1], F_SETFD, 0) < 0)
		die("fcntl");
	unsetenv("WAYLAND_SOCKET");
	if (setenv("WAYLAND_DISPLAY", addr.sun_path, 1) < 0)
		die("setenv");
	execvp(argv[4], argv + 4);
	die(argv[4]);
}
