# Hello World

This is very simple `bin` crate generated by `cargo new`, with no additional
modification. It is built using the latest stable Rust, as provided by
[rust-overlay](https://github.com/oxalica/rust-overlay).

## Introduction

This guide will explain how to build your first Cargo crate with `cargo2nix`. We
assume that you already have the [Nix package manager] installed on your machine
before we get started.

[nix package manager]: https://nixos.org/nix/
[nix flakes]: https://nixos.wiki/wiki/Flakes#Installing_flakes

As described in the official README, `cargo2nix` itself is made up of two
distinct components:

1. A command-line tool which processes a given `Cargo.toml` and `Cargo.lock` and
   produces an equivalent `Cargo.nix` file.
2. A [Nixpkgs overlay] which provides functions for building the `Cargo.nix`
   using a specified version of the Rust toolchain.

[nixpkgs overlay]: https://nixos.wiki/wiki/Overlays

Let's take a look at how to build a minimal `bin` crate generated by `cargo new`
using `cargo2nix`.

## Getting started

Unlike classic nix way we don't need to install cargo2nix globally, we'll get it
later from cargo2nix flake directly.

## Generating flake.nix

First, we need to generate `flake.nix` which is the entrypoint of the project
build system.

```bash
nix flake init
```

## Generating the Cargo project

The canonical way to generate a new binary crate project with Cargo is to run
`cargo new <name>`. However, this requires us to have some version of the Rust
toolchain installed on our system. Furthermore in later steps we'll define
a specific rust version used for building and it's desirable to use the same
version for project generation.

Add `rust-overlay` to get rust version used in the project:

```nix
{
  inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
    utils.url = github:numtide/flake-utils;
  };

  outputs = { nixpkgs, utils, rust-overlay, ... }: utils.lib.eachDefaultSystem (system:
    let
      rustChannel = "stable";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          rust-overlay.overlay
          (
            self: super: {
              rustStable = (
                super.rustChannelOf {
                  channel = rustChannel;
                }
              ).rust;
            }
          )
        ];
      };
    in
    {
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          rustStable
        ];
      };
    }
  );
}
```

Enter temporary shell which will download and install rust version specified in flake.nix:

```bash
nix develop
```

Now that we're inside this shell, let's create the `hello-world` crate we wish
to build:

```bash
cargo init --name hello-world
```

This should create a a mostly empty `Cargo.toml` and `src/main.rs` file.

## Wrapping with cargo2nix

So far, so standard. We have been dealing mostly with standard Nix and Cargo
commands up until this point. Now we are ready to begin wrapping up our
`hello-world` crate with `cargo2nix`.

### Generating a Cargo.nix

As mentioned in the above [introduction](#introduction), we need to generate a
`Cargo.nix` file from our crate's `Cargo.toml` and `Cargo.lock` in order to use
`cargo2nix`. While our project contains a `Cargo.toml`, it doesn't have a
`Cargo.lock` file yet.

While you could make one appear by building your project with `cargo build` for
the first time, you can also generate one with this command:

```bash
cargo generate-lockfile
```

Next, run the following command in the project root to make a `Cargo.nix` file:

```bash
nix run github:cargo2nix/cargo2nix -- -f
```

If you check the current directory with `ls`, you should see that there is now a
`Cargo.nix` file residing alongside the `Cargo.toml` and `Cargo.lock` from
earlier. This Nix expression describes the dependency graph of your Cargo crate
or [crate workspace] in a way that Nix can understand.

[crate workspace]: https://doc.rust-lang.org/edition-guide/rust-2018/cargo-and-crates-io/cargo-workspaces-for-multi-package-projects.html

> Any time that you modify the `Cargo.toml` or `Cargo.lock` file for your
> project, you should always remember to re-run `cargo2nix -f` to update the
> `Cargo.nix` as well.

The final step is to put build instruction to a `flake.nix` file.

### Configuring flake.nix

In order to build our project with `nix build`, we need to have a package defined
in the `flake.nix`. To do so we need to add `cargo2nix` input to our flake,
add `cargo2nix.overlay` to `pkgs` and specify a `defaultPackage` which contains
build instructions:

<pre>
{
  inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
    utils.url = github:numtide/flake-utils;
    <b>cargo2nix.url = github:onsails/cargo2nix/flake;</b>
  };

  outputs = { nixpkgs, utils, rust-overlay, ... }: utils.lib.eachDefaultSystem (system:
    let
      rustChannel = "stable";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          rust-overlay.overlay
          <b>cargo2nix.overlay</b>
          (
            self: super: {
              rustStable = (
                super.rustChannelOf {
                  channel = rustChannel;
                }
              ).rust;
            }
          )
        ];
      };
      <b>
      rustPkgs = pkgs.rustBuilder.makePackageSet' {
        inherit rustChannel;
        packageFun = import ./Cargo.nix;
      };
      </b>
    in
    {
      devShell = pkgs.mkShell {
        <b>defaultPackage = rustPkgs.workspace.hello-world { };</b>

        buildInputs = with pkgs; [
          rustStable
        ];
      };
    }
  );
}
</pre>

Check:

```bash
nix flake show
```

This will show the structure of our flake:

```text
git+file:///home/user/cargo2nix?dir=examples-flakes%2f1-hello-world
├───defaultPackage
│   ├───aarch64-linux: package 'hello-world'
│   ├───i686-linux: package 'hello-world'
│   ├───x86_64-darwin: package 'hello-world'
│   └───x86_64-linux: package 'hello-world'
└───devShell
    ├───aarch64-linux: development environment 'nix-shell'
    ├───i686-linux: development environment 'nix-shell'
    ├───x86_64-darwin: development environment 'nix-shell'
    └───x86_64-linux: development environment 'nix-shell'
```

## Building

To compile the `hello-world` binary with Nix, simply run:

```bash
nix build .
```

This will create a `result` symlink in the current directory with the following
structure:

```text
result
├── bin
│   └── hello-world
├── lib
└── nix-support
    └── propagated-build-inputs
```

Running the `hello-world` binary will print the following message to the screen:

```text
$ ./result/bin/hello-world
Hello, world!
```

Awesome! You've just built your first Rust project with Nix Flakes using `cargo2nix`.
:tada: