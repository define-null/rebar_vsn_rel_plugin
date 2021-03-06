rebar_vsn_rel_plugin
================

About
----

This plugin will make accurate [semver](http://semver.org) compatible
version strings for your Erlang OTP Releases as long as you are doing
semver style versioning with tags 'v<version>'.

Use
---

Add the following dep specification to the deps tuple of your
`rebar.config`:

    {rebar_vsn_rel_plugin, "",
         {git, "https://github.com/define-null/rebar_vsn_rel_plugin.git",
          {tag, "master"}}},

Then inform rebar that you want this to be used as a plugin like so:

    {plugins, [rebar_vsn_rel_plugin]}.

The plugin will backup you reltool.config, check if it contans semver atom or string and change it to semver version.
After release generate it will copy reltool.config back and remove the backup. If generate fails plugin will notify
you on the other attempt that reltool.config was not restored and you will have to make it manually.

Explanation
-------------

This plugin is designed to take the latest semver
compatible tag and turn it into a semver compatible version for the
OTP Release. One of the key things it does (aside from making sure
that semver is respected) is insure that there is a unique
monotonically increasing version for each commit built. It does this
by creating a version from both the latest tag, the epoch timestamp and
the ref. The ref is actually only there to make the version human
readable.

So lets say you have a repository with the tag `v0.0.1` and the epoch
`1348518514` on the latest commit identified by `26ff3c6` then you
would end up with the version `0.0.1+build.1348518514.26ff3c6`. While
that version string is long, it is perfectly accurate, semver
compatible, and works well with OTP. This solves many of the current
versioning problems with rebar and erlang OTP Releases.

FIXME: Bug with empty git repository exists. Need to switch from os:cmd to erlang:open_port to check
returning code.
