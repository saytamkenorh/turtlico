=======================
Reference documentation
=======================

This page contains description for commands in Turtlico.

Comment
=======

Comments are icons with an editable label.
Their purpose is to explain parts of the program.

Go forward
==========

Moves the turtle forward.

**Parameters**

``NUMBER`` Distance in pixels (default: 30)

Turn left
=========

Turns the turtle left.

**Parameters**

``NUMBER`` Angle in degrees (default: 90)

Turn right
==========

Turns the turtle right.

**Parameters**

``NUMBER`` Angle in degrees (default: 90)

Set heading angle
=================

Sets the heading angle of the turtle.

**Parameters**

``NUMBER`` Angle in degrees (default: 0)

Speed
=====

Set the speed of the turtle to a value in range 0..10.
Zero represents the fastest speed (no animations).
Otherwise greater number means faster speed.
If input is smaller than 0.5 or greater than 10 the speed is set to zero.


**Parameters**

``NUMBER`` Speed (default: 1)

Number
=========

This editable icon represents an integer number.

String
=========
This editable icon represents a string.

Length of (string, list etc)
============================

Gets the length of the object.
For example, number of items in a collection or count of characters in a string.

**Parameters**

``OBJECT`` The object whose length is to be obtained

Set position
============

Set position of the turtle. The movement is animated.

**Parameters**

``NUMBER`` The new X coordinate (default: 0)

``NUMBER`` The new Y coordinate (default: 0)

Set pen color
=============

Set color of Turtle's pen. Without any parameters the color is set to black.

**Variants (overloads)**

``STRING`` Color string, such as "red", "yellow", or "#33cc8c"

``TUPLE(r, g, b)`` Color tuple that represents RGB color. Each of r, g and b must be in the range 0..255.

Pull the pen up – no drawing when moving
========================================
The turtle will no longer draw when moving.

Pull the pen down – drawing when moving
=======================================
The turtle will draw a line when moving.

Pen properties
==============
Return or set the pen’s attributes. All the parameters are optional.

**Parameters**

``BOOL`` "shown" `See Hide turle <#hide-turtle>`_

``BOOL`` "pendown" `See Pull the pen up <#pull-the-pen-up-no-drawing-when-moving>`_

``STRING | TUPLE(r, g, b)`` "pencolor" `See Set Pen Color <#set-pen-color>`_

``STRING | TUPLE(r, g, b)`` "fillcolor" Color that is used to fill shapes. Same format as "pencolor".

``NUMBER`` "pensize" Size of line that is Turtle drawing.

``NUMBER`` "speed" `See Speed <#speed>`_

``STRING``  "resizemode" Adaption of the turtle’s appearance. Possible values: "auto" or "user" or "noresize"

``NUMBER, NUMBER`` "stretchfactor" Scale of turtle's shape. "resizemode" must be set to "user".

``NUMBER`` "outline" The width of the shapes’s outline. "resizemode" must be set to "user".

``NUMBER`` "tilt" Rotate the turtleshape by angle from its current tilt-angle.

Hide turtle
===========

Hides the turtle.

Show turtle
===========

Shows the turtle.

Write text on screen
====================

**Parameters**

``STRING`` Text to write

``FONT`` "font" A `font <#font-property-or-editable>`_. (optional)

``STRING`` "align" Possible values: 'left', 'center', 'right'. (optional)

Begin fill
==========
To be called just before drawing a shape to be filled.
Call this, draw a shape (eg. rectangle) and then call `End fill <#end-fill>`_

End fill
=========
Fill the shape drawn after the last call to `Begin fill <#begin-fill>`_

Clear turtle screen
===================
Delete the turtle’s drawings from the screen

Get or set the color of the screen
==================================

**Parameters**

``STRING | TUPLE(r, g, b)`` The new color of the screen. See `this <#set-pen-color>`_ to check out how to specify colors. Do no pass any value to this parameter to get current color.

Get or set the background picture of the screen
===============================================

**Parameters**

``PICTURE | STRING`` The new backgroud picture. It cloud be a string path name or an `image <#id3>`_.

Image
=====

Editable object that represents an image file.
Drag and drop an image from file explorer to your program directly or put this icon into the program and enter path by pressing F2 manually.

Set turtle shape
================
You can change turtle's appearance with this command.

**Variants (overloads)**

``STRING`` Set turtle appearance to a predefined shape 'arrow', 'turtle', 'circle', 'square', 'triangle', 'classic'.

``IMAGE``  Set turtle apperance to an `image <#id3>`_.

Create new turtle
=================
This creates a turtle. The result of this function should be stored in a variable.
All turtle functions can be accessed from this variable.

Get the predefined turtle object
================================
Returns predefined turtle object. It works then just like turtle object returned by `Create new turtle <#create-new-turtle>`_.

Place image at the position of the turtle
=========================================

**Parameters**

``Image`` An `image <#id3>`_.

``Turtle`` A turtle object to place the image at. (optional)

Sleep n seconds (freezes window)
================================
Freezes window for n seconds. During the freez the window does not accept any user input.

**Parameters**

``NUMBER`` Number of seconds to wait.

Connect a function to handle collision (in circle collider of specified radius) between two turtles
===================================================================================================

``TURTLE`` Turtle object A.

``TURTLE`` Turtle object B.

``FUNCTION`` Callback. This function is called when collision occurs.

``NUMBER`` Collider size of turtle A. (default: 10)

``NUMBER`` Collider size of turtle B. (default: 10)

``OBJECT`` User data to pass to callback. (optional)

Connect a function to handle collision (in rectangle collider of specified size) between two turtles
====================================================================================================

``TURTLE`` Turtle object A.

``TURTLE`` Turtle object B.

``FUNCTION`` Callback. This function is called when collision occurs.

``TUPLE (width, height)`` Collider size of turtle A. (default: (15, 15))

``TUPLE (width, height)`` Collider size of turtle B. (default: (15, 15))

``OBJECT`` User data to pass to callback. (optional)

Undo the last turtle action
===========================
Undoes the last turtle action. For example removes drawen line and moves turtle to previous position.

Exit the program
================

**Parameters**

``NUMBER`` Program return code. (default: 0)

Color (property or editable)
============================
This icon represents a color. You can edit it by pressing F2. If no color is set it represents color property.

When a color is set and it is placed standalone into the program it changes turtle's pen color.

Font (property or editable)
===========================
Represents a font description string. Press F2 to edit.

Key
===
Represents a key. Press F2 to edit.

Random number
=============
Return a ranom number in range.

**Parameters**

``NUMBER`` Minimum (default: 0)

``NUMBER`` Maximum (default: 100)

Return list of numbers in specified range
=========================================

**Parameters**

``NUMBER`` Start (default: 0)

``NUMBER`` End (default: 100)

Connect a function to handle mouse clicks
=========================================

**Parameters**

``FUNCTION`` Callback. Two variables - x and y are passed to tihs function.

``NUMBER`` "num" Number of the mouse-button. Defaults to left mouse button. (default: 1)

``BOOL`` "add" If True, a new binding will be added, otherwise it will replace a former binding. (optional)

Connect a function to handle key presses
========================================

**Parameters**

``FUNCTION`` Callback. This is called when "key" is pressed.

``KEY`` "key" See `See <#key>`_.

Call a function after n miliseconds
===================================
Calls a function after n miliseconds.
You can put this command at the end of the callback and then call it once manually to call it repeatedly.

**Parameters**

``FUNCTION`` Callback. A function with no arguments.

``NUMBER`` Number of milliseconds to call the function after.

Number input
============
Pop up a dialog window for input of a number.

**Parameters**

``STRING`` Title of the window. (default: 'Number')

``STRING`` Prompt text. (default: 'Enter a number:')

``NUMBER`` "default" Default number. (optional)

``NUMBER`` "minval" Min value. (optional)

``NUMBER`` "maxval" Max value. (optional)

String input
============
Pop up a dialog window for input of a string.

**Parameters**

``STRING`` Title of the window. (default: 'String')

``STRING`` Prompt text. (default: 'Enter a string:')

Read all lines of a file
========================
Returns an array of strings.

**Parameters**

``STRING`` File path

Write lines to a file
=====================
Writes a string array to a file.

**Parameters**

``STRING`` File path

File dialog
================
Opens a file dialog a lets user to choose a file.
Returns file path as string.

**Parameters**

``STRING`` "text" Text to show in the header of the dialog. (default: 'Choose a file')

``STRING`` "filter" File filter. Format: '[Filter name] | [File name pattern]'. (default: 'All files | *')

``BOOL`` "save" Activate file save mode.

Check file exists
=================
Returns boolean.

**Parameters**

``STRING`` File path

Check directory exists
=================
Returns boolean.

**Parameters**

``STRING`` Directory path

Delete file or directory
========================
This deletes the specified directory or file.

**Parameters**

``STRING`` File/directory path.

Get files in DIRECTORY
======================
Returns a sorted list of subfiles in the specified directory.

**Parameters**

``STRING`` Directory path.

Get subdirs in DIRECTORY
========================
Returns a sorted list of subdirs in the specified directory.

**Parameters**

``STRING`` Directory path.

Get parent directory / the directory the item is located in
============================================================
Returns the parent directory. Eg. for '/dir1/dir2/file' this returns '/dir1/dir2'.

**Parameters**

``STRING`` Path.
