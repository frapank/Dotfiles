#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/syscall.h>
#include <unistd.h>

/* the scopes are Landlock ABI 6 and the unix socket right ABI 9, older headers do not have them */
#define SCOPE_ABSTRACT_UNIX_SOCKET (1ULL << 0)
#define SCOPE_SIGNAL (1ULL << 1)
#define ACCESS_FS_RESOLVE_UNIX (1ULL << 16)
#define ABI_SCOPES 6
#define CREATE_RULESET_VERSION (1U << 0)
#define RULE_PATH_BENEATH 1

struct ruleset_attr {
    __u64 handled_access_fs;
    __u64 handled_access_net;
    __u64 scoped;
};

struct path_beneath_attr {
    __u64 allowed_access;
    __s32 parent_fd;
} __attribute__((packed));

static void die(const char *what)
{
    fprintf(stderr, "landlock-scope: %s: %s\n", what, strerror(errno));
    exit(1);
}

static int usage(void)
{
    fprintf(stderr, "usage: landlock-scope [-u PATH]... COMMAND [ARGS...]\n"
            "Runs COMMAND without the abstract unix sockets and the signals of the\n"
            "processes outside it, and with no pathname unix sockets but the ones\n"
            "under each PATH.\n");
    return 2;
}

static void allow_unix(int ruleset, const char *path)
{
    struct path_beneath_attr rule = { .allowed_access = ACCESS_FS_RESOLVE_UNIX };

    if ((rule.parent_fd = open(path, O_PATH | O_CLOEXEC)) < 0) {
        /* e.g. no audio socket */
        if (errno == ENOENT)
            return;
        die(path);
    }
    if (syscall(SYS_landlock_add_rule, ruleset, RULE_PATH_BENEATH, &rule, 0) < 0)
        die(path);
    close(rule.parent_fd);
}

int main(int argc, char *argv[])
{
    struct ruleset_attr attr = {
        .handled_access_fs = ACCESS_FS_RESOLVE_UNIX,
        .scoped = SCOPE_ABSTRACT_UNIX_SOCKET | SCOPE_SIGNAL,
    };
    const char *paths[argc];
    int i = 1, n = 0, k, ruleset, sockets = 1;
    long abi;

    for (; i + 1 < argc && !strcmp(argv[i], "-u"); i += 2)
        paths[n++] = argv[i + 1];
    if (i < argc && !strcmp(argv[i], "--"))
        i++;
    if (i >= argc || argv[i][0] == '-')
        return usage();

    abi = syscall(SYS_landlock_create_ruleset, NULL, 0, CREATE_RULESET_VERSION);
    if (abi < ABI_SCOPES) {
        /* the sandbox still has bwrap and AppArmor around it */
        fprintf(stderr, "landlock-scope: no Landlock scopes in this kernel, %s runs without\n", argv[i]);
    } else {
        ruleset = syscall(SYS_landlock_create_ruleset, &attr, sizeof(attr), 0);
        if (ruleset < 0 && errno == EINVAL) {
            fprintf(stderr, "landlock-scope: this kernel cannot restrict pathname unix sockets\n");
            attr.handled_access_fs = 0;
            sockets = 0;
            ruleset = syscall(SYS_landlock_create_ruleset, &attr, sizeof(attr), 0);
        }
        if (ruleset < 0)
            die("landlock_create_ruleset");
        for (k = 0; sockets && k < n; k++)
            allow_unix(ruleset, paths[k]);
        if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) < 0)
            die("no_new_privs");
        if (syscall(SYS_landlock_restrict_self, ruleset, 0) < 0)
            die("landlock_restrict_self");
        close(ruleset);
    }
    execvp(argv[i], argv + i);
    die(argv[i]);
}
