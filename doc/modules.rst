=======
Plugins
=======

Turtlico is extensible by plugins that can add extra icons.
For example, the integrated RPi plugin adds commands to control GPIO via the gpiozero library.

Activating a deactivating plugins is done in Project settings.

You can open the plugins folder by clicking *Open plugins folder* button in Project settings. There you can put your additional plugins.

=======================
Creating custom plugins
=======================

Every set of commands has its own file.
Turtlico loads these files from data dirs (eg. ``/usr/share/turtlico/plugins``) and also from GResources with prefix ``/tk/turtlico/Turtlico``.
Plugins can also contain custom icons.

Plugins loaded from filesystem
==============================
Plugins can be stored in form of files on the local filesystem.
Every plugin has its own folder.

There is a plugin file called ``commands.json`` and there are also custom icons in every folder.

Turtlico searches for plugins in all data directories.
The most often ones are listed here:

+--------------------+-----------------------------------------------------------+
| **Windows**        | ``C:/ProgramData/turtlico/plugins``                       |
|                    | ``C:/Users/[username]/AppData/Local``                     |
+--------------------+-----------------------------------------------------------+
| **Linux**          | ``/usr/share/turtlico/plugins``                           |
|                    | ``~/.local/share/turtlico/plugins``                       |
+--------------------+-----------------------------------------------------------+
| **Linux (Flatpak)**| ``/usr/share/turtlico/plugins``                           |
|                    | ``~/.var/app/tk.turtlico.Turtlico/data/turtlico/plugins`` |
+--------------------+-----------------------------------------------------------+

**Basic plugin folder structure**

| plugins
| └── [plugin name]
|     ├──commands.json
|     └──[PNG icon files]


GResources plugins
==================
This is mostly used by the internal Turtlico plugins.

Plugin file resource has to be installed as a child of path ``/tk/turtlico/Turtlico``.
Unlike plugins loaded from filesystem GResources plugin file should be named like the plugin itself eg. ``example.json``.

Icon files has to be children of ``/tk/turtlico/Turtlico/icons``.

Format of plugin files
======================

**Basic structure**

Module files are json-formated. This is a basic module file with one category and one command:

.. code-block:: json
    :force:

    {
        "name": "Example plugin",
        "categories": [
            {
                "icon" : "",
                "commands": [
                    {"id":"0_example", "icon":"r:example.png", "?": 'Example', "type": -1}
                ]
            }
        ],
        "modules": [
        ],
        "events": [
        ]
    }

**Name of the plugin**

The name that is shown in the project settings dialogue.

**Categories**

Every module contains categories - groups that are shown in the right menu of the program. You need to specify an icon (see below) and commands that the category contains.

**Modules (optional)**

Modules are blocks of commands that are represented by a single icon. You need to define the module and a corresponding command. The command should be type 0 or 5.

If the module name is same as name of the plugin directory or it is a GReosource file name then the module will be always loaded.
To this kind of modules you can put imports and the other inicialisation stuff.

Properties:

- ``id`` - The ID of the module. This must be same as the ``func`` property of the corresponding command.
- ``code`` - A piece of code that is placed before the generated code to the output file. It should define a method with an id that corresponds with the id property of the module.
- ``deps`` - You can use other modules from a module. This specifies a list of modules that will be inserted into the program with the module.

Example:

.. code-block:: json
    :force:

    {
        "id": "tcf_sum",
			"code": "def tcf_sum(a, b):\
        return a + b"
    },

Example corresponding command definition:

.. code-block:: json
    :force:

    {"id":"5_sum", "icon":"r:sum.png", "?": 'Returns the sum of two numbers.' , "type": 5, "func": "tcf_sum", "params": "" }

**Events (optional)**

Functions dialog provides an option to create new methods and also automatically connect functions to events.

Properties:

- ``name`` - The name of the event.
- ``code`` - Default code in newly created function. Use $name to get name of the function.
- ``connector`` - A piece of code that is used to connect the event to a function in string format. Use $name to get name of the function.
- ``params`` - Default parameters for functions that are connected to this event.

Example:

.. code-block:: json

    {"name":"Key press", "code":""}


Command specification
======================

Basic properties:

- ``id`` - The ID of the command. It should have a prefix that corresponds with the icon type. Eg. ``0_go``.
- ``icon`` - The icon of the command (see Icon specification).
- ``?`` - Basic short description of the icon.
- ``type`` - The type of the command. See below.
- ``snippet`` - Block of code in string format that is inserted at position of the command when autocomplete is performed.

**Command types**

- -1 - This is an internal type. It indicates that command has its own processing code in the compiler. This should not be used in the icon prefix.
- 0 - Basic method. You must specify two extra properties: ``func`` (Python method name eg. ``forward``) and ``params`` (default parameters separated by commas that are passed to the method if the icon is placed standalone eg ``"50, 40"``)
- 2 - Operator. E.g. Assign value, increase value by, etc. Command that immediately follows an operator is placed on the same line as the operator in the output file.
- 3 - Keyword. It is a command that is on its own line and it doesn't need any parameters in parenthesis. You need to specify propery ``c`` that indicates which keyword is put instead of the icon to the python code (eg. ``break``).
- 4 - Simple code snippet. Use that for icons that represent a simple Python snippet like constants, variables etc. You need to specify property ``c`` that contains the code (eg. ``"math.pi"``).
- 5 - Obsolete since version 0.4: Doesn't have any effect anymore. Please use 0 type for all commands. Function that returns a value - Like Basic method but this is not put always on its own line.
- 6 - Keyword that takes arguments. Like If or For cylcles. Following commands upto : or Enter are placed on the same line in the output file.

Icon specification
======================

There are three options to specify icons in plugin files:

1. Plain text - use text and/or emoji to make the icon simple to understand
2. GResources - Loads icon from Turtlico resources(``/tk/turtlico/Turtlico/icons/*``). It must start with ``"r:"``. Eg. ``r:example_icon.png``.
3. Local file - Loads PNG icon from plugin dir. It must start with ``"f:"``. Eg. ``f:example_icon.png``.
