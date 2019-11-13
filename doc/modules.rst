=======
Modules
=======

Turtlico is extensible by modules that can add extra icons.
For example, the integrated RPi plugin adds commands to control GPIO via the gpiozero library.

Every set of commands has its own file. Turtlico loads these files from user data dirs (eg. ``/usr/share/turtlico/plugins``) and also from GResources with prefix ``/com/orsan/Turtlico``.

Format of module files
======================

**Basic structure**

Module files are json-formated. This is a basic module file with one category and one command:

.. code-block:: json
    :linenos:

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
        ]
    }

**Name of the plugin**

The name that is shown in the project settings dialogue.

**Categories**

Every module contains categories - groups that are shown in the right menu of the program. You need to specify an icon (see below) and commands that the category contains.

**Modules (optional)**

Modules are blocks of commands that are represented by a single icon. You need to define the module and a corresponding command. The command should be type 0 or 5.

Properties:

- ``id`` - The ID of the module. This must be same as the ``func`` property of the corresponding command.
- ``code`` - A piece of code that is placed before the generated code to the output file. It should define a method with an id that corresponds with the id property of the module.

Example:

.. code-block:: json
    :linenos:

    {
        "id": "tcf_sum",
			"code": "def tcf_sum(a, b):\
        return a + b"
    },

Example corresponding command definition:

.. code-block:: json
    :linenos:

    {"id":"5_sum", "icon":"r:sum.png", "?": 'Returns the sum of two numbers.' , "type": 5, "func": "tcf_sum", "params": "" }

Command specification
======================

Basic properties:

- ``id`` - The ID of the command. It should have a prefix that corresponds with the icon type. Eg. ``0_go``.
- ``icon`` - The icon of the command (see Icon specification).
- ``?`` - Basic short description of the icon.
- ``type`` - The type of the icon. See below.

**Command types**

- -1 - This is an internal type. It indicates that command has its own processing code in the compiler. This should not be used in the icon prefix.
- 0 - Basic method. You must specify two extra properties: ``func`` (Python method name eg. ``forward``) and ``params`` (default parameters separated by commas that are passed to the method if the icon is placed standalone eg ``"50, 40"``)
- 3 - Keyword. It is a command that is on its own line and it doesn't need any parameters in parenthesis. You need to specify propery ``c`` that indicates which keyword is put instead of the icon to the python code (eg. ``break``).
- 4 - Simple code snippet. Use that for icons that represent a simple Python snippet like constants, variables etc. You need to specify property ``c`` that contains the code (eg. ``"math.pi"``).
- 5 - Function that returns a value - Like Basic method but this is not put always on its own line.

Icon specification
======================

There are two options to specify icons in module files:

1. Plain text - use text and/or emoji to make the icon simple to understand
2. GResources - Loads icon from Turtlico resources(``/com/orsan/Turtlico/icons/*``). It must start with ``"r:"``. Eg. ``r:example_icon.png``..
