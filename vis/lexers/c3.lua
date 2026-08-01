local lexer = require('lexer')
local token, word_match = lexer.token, lexer.word_match
local P, S, R, B = lpeg.P, lpeg.S, lpeg.R, lpeg.B

local lex = lexer.new('c3')

local keywords = word_match{
	'alias', 'assert', 'asm', 'attrdef', 'bitstruct', 'break', 'case', 'catch',
	'const', 'constdef', 'continue', 'default', 'defer', 'do', 'else', 'enum',
	'extern', 'false', 'fault', 'faultdef', 'for', 'foreach', 'foreach_r',
	'fn', 'if', 'import', 'inline', 'interface', 'lengthof', 'macro', 'module',
	'nextcase', 'null', 'return', 'scope', 'static', 'struct', 'switch',
	'tlocal', 'true', 'try', 'typedef', 'union', 'var', 'while'
}

local types = word_match{
	'any', 'void', 'bool', 'char', 'double', 'float16', 'bfloat', 'bfloat16',
	'float128', 'int128', 'int', 'ichar', 'iptr', 'sz', 'long', 'short',
	'uint128', 'uint', 'ulong', 'uptr', 'ushort', 'usz', 'float', 'typeid',
	'fault'
}

local attributes = word_match{
	'align', 'benchmark', 'bigendian', 'builtin', 'cdecl', 'cname',
	'deprecated', 'dynamic', 'export', 'extname', 'inline', 'interface',
	'littleendian', 'local', 'maydiscard', 'mustinit', 'naked', 'nodiscard',
	'noinit', 'noinline', 'noreturn', 'nostrip', 'obfuscate', 'operator',
	'overlap', 'packed', 'priority', 'private', 'public', 'pure', 'reflect',
	'section', 'stdcall', 'test', 'unused', 'used', 'veccall', 'wasm',
	'weak', 'winmain'
}

local word = lexer.word

local line_comment = lexer.to_eol('//', true)
local hashbang = lexer.to_eol('#!', true)
local block_comment = lexer.range('/*', '*/')
local contract_comment = lexer.range('<*', '*>')
lex:add_rule('comment', token(lexer.COMMENT, line_comment + hashbang + block_comment + contract_comment))

local known_attribute = token(lexer.KEYWORD, P('@') * attributes)
local other_annotation = token(lexer.PREPROCESSOR, P('@') * word)
lex:add_rule('annotation', known_attribute + other_annotation)

local dq_prefix = (S('cx') + P('b64'))^-1
local raw_prefix = (P('x') + P('b64'))^-1
local char_prefix = (P('x') + P('b64'))^-1

local dq_str = dq_prefix * lexer.range('"', true)
local raw_str = raw_prefix * lexer.range('`')
local multiline_str = dq_prefix * P('\\\\') * lexer.nonnewline^0

local string_literal = token(lexer.STRING, dq_str + raw_str + multiline_str)
local char_literal = token(lexer.STRING, char_prefix * lexer.range("'", true))
lex:add_rule('string', string_literal + char_literal)

lex:add_rule('ct_builtin', token(lexer.FUNCTION_BUILTIN, P('$$') * word))

local ct_types = P('$') * word_match{ 'Typeof', 'Typefrom' }
lex:add_rule('ct_type', token(lexer.TYPE, ct_types))

lex:add_rule('ct_keyword', token(lexer.KEYWORD, P('$') * word))

local fixed_int_types = token(lexer.KEYWORD, S('iu') * R('09')^1 * -word)
lex:add_rule('fixed_int', fixed_int_types)

lex:add_rule('keyword', token(lexer.KEYWORD, keywords))

local all_caps_constant = R('AZ') * (R('AZ', '09') + P('_'))^0 * -R('az')
lex:add_rule('constant', token(lexer.CONSTANT, all_caps_constant))

local capitalized_type = R('AZ') * word^-1
lex:add_rule('type', token(lexer.TYPE, capitalized_type + types))

local namespace = token(lexer.KEYWORD, word) * #(lexer.space^0 * '::')
lex:add_rule('namespace', namespace)

local func_call = token(lexer.FUNCTION, word) * #((S(' \t')^0) * '(')
lex:add_rule('function', func_call)

local dec = R('09') * (R('09') + P('_'))^0
local hex = R('09', 'af', 'AF') * (R('09', 'af', 'AF') + P('_'))^0
local oct = R('07') * (R('07') + P('_'))^0
local bin = S('01') * (S('01') + P('_'))^0
local integer = (P('0x') + '0X') * hex
              + (P('0o') + '0O') * oct
              + (P('0b') + '0B') * bin
              + dec
local float = dec^-1 * P('.') * dec * (S('eE') * S('+-')^-1 * dec)^-1 * S('fFdD')^-1
            + dec * S('eE') * S('+-')^-1 * dec * S('fFdD')^-1
lex:add_rule('number', token(lexer.NUMBER, float + integer))

lex:add_rule('operator', token(lexer.OPERATOR, S('+-/*%<>!=^&|?~:;,.()[]{}')))

lex:add_rule('identifier', token(lexer.IDENTIFIER, word))

lex:add_fold_point(lexer.OPERATOR, '{', '}')
lex:add_fold_point(lexer.COMMENT, '/*', '*/')
lex:add_fold_point(lexer.COMMENT, '<*', '*>')

return lex