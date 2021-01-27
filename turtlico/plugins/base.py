# flake8: noqa
from turtlico.compiler import Plugin, CommandCategory, CommandColor
from turtlico.compiler import CommandDefinition, CommandType, CommandModule, CommandEvent, icon
from turtlico.locale import _

name='Base'

def get_plugin():
    p = Plugin(name)
    p.categories.extend([
        CommandCategory(p, '⚙', [
            CommandDefinition('nl', '⏎', _('New line (enter)'), CommandType.INTERNAL, color=CommandColor.INDENTATION),
            CommandDefinition('tab', '·', _('Tab'), CommandType.INTERNAL, color=CommandColor.INDENTATION),
            CommandDefinition('#', '#', _('Comment'), CommandType.INTERNAL, color=CommandColor.COMMENT, has_data=True, data_only=True),
            CommandDefinition('sep', ',', _('Argument separator (Comma)'), CommandType.CODE_SNIPPET, ','),
            CommandDefinition('(', ',', _('Left parenthesis'), CommandType.CODE_SNIPPET, '('),
            CommandDefinition(')', ',', _('Right parenthesis'), CommandType.CODE_SNIPPET, ')'),
            CommandDefinition('if', '❔if', _('If statement'), CommandType.KEYWORD_WITH_ARGS, 'if', snippet='if,;true,;:,;nl,;tab,;'),
            CommandDefinition('else', 'else', _('Else'), CommandType.KEYWORD_WITH_ARGS, 'else'),
            CommandDefinition(':', ':', _('Begin block of commands'), CommandType.CODE_SNIPPET, ':'),
            CommandDefinition('&', 'and', _('and'), CommandType.CODE_SNIPPET, ' and '),
            CommandDefinition('||', 'or', _('or'), CommandType.CODE_SNIPPET, ' or '),
            CommandDefinition('!', 'not', _('negation'), CommandType.CODE_SNIPPET, ' not '),
            CommandDefinition('==', '==', _('equals'), CommandType.CODE_SNIPPET, '=='),
            CommandDefinition('!=', '!=', _('not equals'), CommandType.CODE_SNIPPET, '!='),
            CommandDefinition('<', '<', _('is less than'), CommandType.CODE_SNIPPET, '<'),
            CommandDefinition('>', '>', _('is greater than'), CommandType.CODE_SNIPPET, '>'),
            CommandDefinition('rep', icon('base/rep.svg'), _('Repeat block of commands'), CommandType.INTERNAL, color=CommandColor.CYCLE, snippet='rep;int,2;:;nl;tab;'),
            CommandDefinition('for', 'for', _('For loop'), CommandType.KEYWORD_WITH_ARGS, 'for', color=CommandColor.CYCLE, snippet='for;obj,n;in;range;(;int,0;sep;int,10;);:;nl;tab;'),
            CommandDefinition('in', 'in', _('is item in an list? / for items in a colletion'), CommandType.CODE_SNIPPET, 'in'),
            CommandDefinition('while', icon('base/while.svg'), _('Repeat while the condition is true'), CommandType.KEYWORD_WITH_ARGS, 'while', color=CommandColor.CYCLE, snippet='while;true;:;nl;tab;'),
            CommandDefinition('b', '🛑', _('Break out of a loop'), CommandType.KEYWORD, 'break', color=CommandColor.KEYWORD),
            CommandDefinition('c', '↦', _('Continue with the next iteration of a loop'), CommandType.KEYWORD, 'continue', color=CommandColor.KEYWORD),
            CommandDefinition('def', 'def', _('Define a function'), CommandType.INTERNAL, color=CommandColor.KEYWORD, snippet='def;obj,name;(;);:;nl;tab;'),
            CommandDefinition('r', icon('base/r.svg'), _('Return a value'), CommandType.KEYWORD_WITH_ARGS, 'return', color=CommandColor.KEYWORD),
            CommandDefinition('[', '[', _('Left square bracket'), CommandType.CODE_SNIPPET, '['),
            CommandDefinition(']', ']', _('Right square bracket'), CommandType.CODE_SNIPPET, ']'),
            CommandDefinition('len', 'len', _('Length of (string, list etc)'), CommandType.METHOD, 'len'),
            CommandDefinition('del', 'del', _('Delete an object'), CommandType.KEYWORD, 'del', color=CommandColor.KEYWORD),
            CommandDefinition('apnd', icon('base/apnd.svg'), _('Append an item to the list'), CommandType.METHOD, 'append'),
            CommandDefinition('ins', icon('base/ins.svg'), _('Insert an item to the list'), CommandType.METHOD, 'insert'),
            CommandDefinition('clr', icon('base/clr.svg'), _('Clear the list'), CommandType.METHOD, 'clear'),
            CommandDefinition('index', icon('base/index.svg'), _('Find index of the first occurence of an item in a list or string'), CommandType.METHOD, 'tcf_index'),
            CommandDefinition('slo', 'aa', _('Convert a string to lower case'), CommandType.METHOD, 'lower'),
            CommandDefinition('sup', 'AB', _('Convert a string to upper case'), CommandType.METHOD, 'upper'),
            CommandDefinition('sspl', icon('base/sspl.svg'), _('Split the string'), CommandType.METHOD, 'split', "'\\n'"),
            CommandDefinition('sspl', icon('base/sspl.svg'), _('Replace a phrase with another phrase in the string'), CommandType.METHOD, 'replace'),
        ])
    ])
    return p
