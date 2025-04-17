# $> CMDS-FRAMEWORK

CMDS-FRAMEWORK, called just `cmds` from this point on, is a zsh framework to
drastically reduce the toil involved with writing robust shell scripts.

Shell scripts are very quick to write and also abstract our systems well.

However, they by default lack argument parsing, argument completion, and
auto-generated descriptions.

Furthermore, having many shell scripts across your machine can be rather
unorganized.

Some will turn to programming languages proper to remedy these issues.
Take Golang for example, there are plenty of argument parsing libraries which
generate zsh completion.

However, by moving to a programming language proper the speed at which scripts
can be written is lost. Shell scripts excel at integrating with your
system with syntax for command substitution, piping, and a host of helper
commands. A programming language proper can do all of this as well, but its
slower to 'hack' things together.

Hence `cmds` was written.
`cmds` integrates directly with `zsh` to make writing scripts that support
argument parsing, nested subcommands, completion, and more, very simple.

Here's what a `cmds` script looks like.

```zsh
desc="A short description of the script"
args=("--one:first argument in zsh's _describe format" \
      "--two:[b,o] second argument with argument options (boolean, optional)")
help=("example", "A long description of the script.

 The description can be a multi-line string without an issue.")


execute() {
    echo $one
    echo $two
}
```

If this looks and sounds exciting to you read on.

# Usage (Walkthrough)

Source `.lib.sh` from your `zshrc`

```sh
$> source ./cmds/.lib.sh
```

Inside the `cmds` directory make a new folder

```sh
$> mkdir ./cmds/new
```

Tab completion will will automatically find your new "subcommand"

```sh
$> cmds{TAB}
example  new
```

Give the subcommand a description

```sh
$> cat new/.description
desc="A new subcommand"
```

Describe the subcommand (no commands created yet)

```sh
$> cmds new
SUMMARY:
  A new subcommand

COMMANDS:
```

Create a "command" by adding a script.
Arguments are automatically parsed into variables.

```sh
$> cat new/new.sh
desc="A new command"
args=("--one:A required argument with a value" \
      "--two:[b,o]A boolean argument that is optional")
help=("new" "A long-form description of the command")

execute() {
	echo "$one"
	if [[ ${+two} -eq 1 ]]; then
		echo "$two"
	fi
}
```

Describing the subcommand now shows our command

```sh
$> cmds new
SUMMARY:
  A new subcommand

COMMANDS:
  new.sh  A new command
```

Tab completion for our command "just works" (help flag is automatically created)

```sh
$> cmds new new.sh --{TAB}
--help  -- [b,o] Display help
--one   -- A required argument with a value
--two   -- [b,o]A boolean argument that is optional
```

Missing required arguments return an error:

```sh
$> cmds new new.sh
ERROR: The following required arguments were not provided:
--one -- A required argument with a value

Usage: new [options]

Options:
  --one  A required argument with a value
  --two  [b,o]A boolean argument that is optional

Description:
 A long-form description of the command
```

Missing values for flags return an error:

```sh
cmds new new.sh --one
ERROR: missing value for flag --one

Usage: new [options]

Options:
  --one  A required argument with a value
  --two  [b,o]A boolean argument that is optional

Description:
 A long-form description of the command
```
# Writing scripts

The goal of `cmds` is to mandate as little boilerplate as possible when writing
scripts, all while providing argument completion, argument parsing, and
argument validation.

A script **MUST** define three variables:

`desc`: A string variable containing a short description.

`args`: An array of strings containing argument specs (more on this below)

`help`: An array of two strings, the first being the name of the script, the
        second being a long-form description (can be a multi-line string).

A script **MUST** define an `execute` function where all the script's content
resides.

A script's `args` are automatically converted to global variables for use
within the script.

If arguments passed to the script are invalid, the script is not invoked and
the framework will print an error, the script's help dialogue, and exit.

## Arguments

The `args` array makes argument parsing, completion, and argument validation
possible.

`args` are defined in a specific format which is slightly modified from
zsh's _describe completion function syntax.

The format is:

`--{flag}:[options]{description}`

`flag`: is the flag's name and **MUST** be prefixed with `--`. Only long-form
flags are supported at this time. Each `flag` must obey zsh's variable naming
constraints as the flag is converted directly to a global variable. These
constraints are expressed by the following regexp `[a-zA-Z_]+[a-zA-Z0-9_]*`.
Variables must start with a letter and only contain letters, numbers, and the
"_" following the first character.

`options`: A comma separated list of options between brackets. Only two options
exist currently:

`o` - optional argument

`b` - boolean argument (does not require a following value)
If both options are desired a comma must separate them `[o,b]`

`description`: A short description of the flag.

Here is an example arguments array:

```sh
args=("--one:first argument in zsh's _describe format" \
      "--two:[b,o] second argument with argument options (boolean, optional)")
```

## Description and help

The `desc` and `help` variables are self explanatory.

Here are examples;

```sh
desc="A short description of the script"
help=("example", "A long description of the script.

 The description can be a multi-line string without an issue.")
```

You are free to populate these strings anyway you'd like.
For instance, if you want a really long description as the second argument
to `help` you can place it in a file and do the following:

```sh
help=("example", $(cat $CMDS_DIR/.description.txt))
```

Notice the use of the hidden file, this ensures `cmds` does not print the file
as a possible subcommand.

## Argument forwarding

The `cmds` framework provides argument forwarding implicitly to all scripts.

Any arguments provided after the "--" (read: argument forwarding argument) will
be fed into an array called $forwarded.

Script authors can then use this array to forward arguments to another binary.

For example, say you are writing a kubectl wrapper.

In your script you can write the following `execute` function:

```sh
execute() {
    kubectl $forwarded
}
```

It is then possible to call this script with "--" and directly pass arguments
to the kubectl command.

```sh
$> cmds k8s ctl.sh -- get pods
```

If you are interested in the details or alternatives to this approach read
the comment for commit: 81086f51

# CMDS-FRAMEWORK in detail

The `cmds` framework aims to make writing robust scripts simple.

Shells however are notoriously tricky and confusing creatures. A deeper dig into
how `cmds` works is warranted.

All of `cmds` functionality exists in the `.lib.sh` file which is designed to
be sourced into your interactive zsh shell.

This file provides several components:

- Variables which are used in the library and useful for script writers as well
- Logging functions for use in both the library and the scripts
- Output helpers for outputting consistent dialogues such as subcommand descriptions
  and help dialogues
- An argument parsing function for converting arguments into script variables
- The command runner which is exported as the function `cmds` itself. This
  takes the completed cli line, converts it to a file system path, and invokes
  the script with any provided arguments.

Lets talk about these in detail below.

## Variables

At the top of `.lib.sh` exists a block of variables.

These are used internally however the `CMDS_DIR` variable is very useful for
script authors. This variable holds the path to the `cmds` directory. Script
writers can use this to source or reference files relative to their own location.

For example a script can reference `$CMDS_DIR/example/.lib` and source this in
to retrieve a common set of functions useful for the `example` subcommand's
context.

Other variables exist and more maybe added over time. Its useful to take a peek
to see if a problem you face can be solved with one.

## Logging

A set of logging functions are exported to your shell when `.lib.sh` is sourced.

```sh
lib_error() {
	local red='\033[0;31m'
	local reset='\033[0m'
	echo -e "${red}$1${reset} "
}

lib_info() {
	local blue='\033[0;34m'
	local reset='\033[0m'
	echo -e "${blue}$1${reset} "
}

lib_warning() {
	local yellow='\033[0;33m'
	local reset='\033[0m'
	echo -e "${yellow}$1${reset} "
}
```

These are handy to have in your scripts for logging different events.

If you source `.lib.sh` from `zshrc` these are also available for you to use
outside of `cmds` framework if you'd like.

## Output helpers

Output helpers are usually heredocs with some initial processing.

These functions like `lib_help` ensures the `cmds` framework provides consistently
formed output to the user.

Not much else to say about these, have a look in `.lib.sh` if you're interested.

## Argument Parser

One of the more complex parts of `.lib.sh`, the argument parser matches runtime
arguments to script arguments and creates variables for the ones that match.

It will also handle validation, ensuring all required arguments are present
and have an associated value (if its not a boolean or optional argument).

The argument parser is ran as part of the command runner which is discussed
next. This means the target script is never even invoked if arguments do not
validate.

Because the argument parser creates variables for desired arguments and will
not invoke the script if arguments are invalid, the script writer can simply
declare arguments in the `$args` array and refer to the argument values as
variables (sans the '--' prefix the arguments are required to be defined with).

## Command Runner

The command runner is defined as the function `cmds`.

This is the function that gets invoked when you hit <ENTER> after a fully
completed command.

The command runner takes the current items in the completed cli command,
converts it to a file path, and sources the target script after parsing
any arguments into variables.

Once the script is sourced and the variables are created the `execute` function
sourced from the script is ran, finally invoking the contents of the script.

The entire command runner runs in a sub-shell. This ensures any call to `exit`
will kill the sub-shell and not the current interactive one. It also ensures
environment changes do not effect the interactive shell.

## The magic of sourcing

One of the most confusing things about the `cmds` framework is its ample use
of sourcing.

When `.lib.sh` sources a script file it loads the script's variables and
arguments into its environment.

Any variables the script defines are accessible, likewise, since the script's
`execute` function is called from the command runner, it also has access to
variables defined in `.lib.sh`.

This results in variables 'magically' being available.

For instance lets look at `lib_describe`:

```sh
lib_describe() {
	# grab each subcommad's descriptions by sourcing each script and reading
	# the $desc variable.
	summary="$1"
	dir="$2"
	local -a cmds=()
	for f in $(ls $dir); do
		if [[ -d $dir/$f ]]; then
			source $dir/$f/.description
		else
			source $dir/$f
		fi
		cmds+=("$f\t$desc\n")
	done

	cat <<EOF
SUMMARY:
  $summary

COMMANDS:
$(for cmd in $cmds; do
	echo "  $cmd"
done | column -t -s $'\t')
EOF
}
```

This function lists describes a subcommand.

To describe a subcommand we get a directory listing of the subcommand's directory.

If the directory entry is a directory we source the `.description` file of the
subdirectory. If its a file we source in the script file itself.

This sourcing makes the $desc variable available to us.

If you're using an LSP or linter it will most likely complain that $desc is
never defined.

This is done all over `.lib.sh` so it warrants an explanation.
Be aware of this when things look a little funny.
