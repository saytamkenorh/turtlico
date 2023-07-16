use std::num::ParseFloatError;
use std::ops::Range;

use logos::Logos;
use chumsky::{prelude::*, Stream};

use crate::ast::{Expression, Spanned};
use crate::error::Error;
use crate::tokens::Token;

pub fn parse(source: &str) -> Result<Spanned<Expression>, Vec<Spanned<Error>>> {
    let lexer = Token::lexer(source);
    let srclen = lexer.source().len();

    let lexer_out = lexer.spanned().collect::<Vec<(Result<Token, ()>, Range<usize>)>>();
    let mut tokens = vec![];
    let mut errors = vec![];
    for (token, span) in lexer_out {
        match token {
            Ok(t) => {
                tokens.push((t, span));
            },
            Err(_) => {
                errors.push(Spanned::new(Error::InvalidToken, span));
            }
        }
    }
    if errors.len() > 0 {
        return Err(errors);
    }

    create_parser().parse(
        Stream::from_iter(
            srclen..srclen+1,
            tokens
            .into_iter()
    )).map_err(|errors| {
        errors.into_iter().map(|err| {
            let span = err.span();
            Spanned::new(Error::SyntaxError(err), span)
        }).collect()
    })
}

pub fn get_tokens(source: &str) -> Vec<Result<Token, ()>> {
    let mut lexer = Token::lexer(source);
    let mut tokens = vec![];
    while let Some(token) = lexer.next() {
        tokens.push(token);
    }
    tokens
}

fn create_parser() -> impl Parser<Token, Spanned<Expression>, Error = Simple<Token>> {
    let expression = recursive(|expr| {
        let block = expr.clone()
                .repeated()
                .delimited_by(just(Token::LeftCurly), just(Token::RightCurly))
                .map(Expression::Block)
                .map_with_span(Spanned::new);
        let literal = filter_map(
            |span, token: Token| match token {
                Token::Integer(x) => Ok(Expression::Int(x)),
                Token::String(x) => Ok(Expression::String(x)),
                Token::Float(x) => x.parse().map_err(
                    |err: ParseFloatError| Simple::custom(span, err.to_string()))
                        .map(|value| Expression::Float(value)),
                    _ => {
                        Err(Simple::custom(span, "Not a literal"))
                    }
            }
        ).map_with_span(Spanned::new);

        let objdef = expr.clone()
            .then_ignore(just(Token::Colon))
            .then(expr.clone())
            .separated_by(just(Token::Comma))
            .delimited_by(just(Token::LeftCurly), just(Token::RightCurly))
            .map(|items|{
                let mut object = vec![];
                for item in items {
                    object.push((item.0, item.1));
                }
                Expression::ObjDef { object: object }
            })
            .map_with_span(Spanned::new);

        let var_name = select! {Token::Variable(x) => x}.map_with_span(Spanned::new);
        let func_name = select! {Token::Function(x) => x}.map_with_span(Spanned::new);

        let var =
            (
                var_name.clone().then_ignore(just(Token::Dot))
                .then(var_name)
                .map(|(parent, key)| {
                    let p_ex = Spanned::new(Expression::Variable { parent: None, name: parent.item }, parent.span);
                    Expression::Variable { parent: Some(Box::new(p_ex)), name: key.item }
                })
            ).or(
                var_name.map(|v| {Expression::Variable { parent: None, name: v.item }})
            )
            .map_with_span(Spanned::new);
        let func =
            (
                var_name.clone().then_ignore(just(Token::Dot))
                .then(func_name)
                .map(|(parent, key)| {
                    let p_ex = Spanned::new(Expression::Variable { parent: None, name: parent.item }, parent.span);
                    Expression::Variable { parent: Some(Box::new(p_ex)), name: key.item }
                })
            ).or(
                func_name.map(|v| {Expression::Variable { parent: None, name: v.item }})
            )
            .map_with_span(Spanned::new);

        // Expressions
        let call = func.clone()
            .then(
                expr.clone()
                    .separated_by(just(Token::Comma))
                    .allow_leading()
                    .delimited_by(just(Token::LeftParent), just(Token::RightParent))
            )
            .map(|(ident, args)| Expression::Call { expr: Box::new(ident), args: args })
            .map_with_span(Spanned::new);

        let shortcall = func.clone()
            .then(literal.clone())
            .map(|(ident, arg)| Expression::Call { expr: Box::new(ident), args: vec![arg] })
            .or(
                func.clone().then(var.clone())
                .map(|(ident, arg)| Expression::Call { expr: Box::new(ident), args: vec![arg] }))
            .or(func.clone().map(|ident| Expression::Call { expr: Box::new(ident), args: vec![] }))
            .map_with_span(Spanned::new);

        let assignment = var.clone()
            .then_ignore(just(Token::Assignment))
            .then(expr.clone())
            .map(|(expr, value)|
                 Expression::Assignment {expr: Box::new(expr), value: Box::new(value)})
            .map_with_span(Spanned::new);

        // Keywords
        let condition = just(Token::If)
            .then(expr.clone())
            .then(expr.clone())
            .map(|((_token, cond), body)| Expression::If {cond: Box::new(cond), body: Box::new(body)})
            .map_with_span(Spanned::new);

        let ret = just(Token::Return).then(expr.clone())
            .map(|(_token, expr)| Expression::Return {value: Box::new(expr)})
            .or(just(Token::Return)
            .map(|_token| Expression::Return{value: Box::new(Spanned::new(Expression::None, 0..0))}))
            .map_with_span(Spanned::new);
        let break_expr = just(Token::Break)
            .map_err(|e: Simple<Token>| Simple::custom(e.span(), "Not break"))
            .map(|_token| Expression::Break)
            .map_with_span(Spanned::new);

        // Loops
        let loop_finite = just(Token::Loop)
            .then(expr.clone())
            .then(expr.clone())
            .map(|((_token, iters), body)| Expression::LoopFinite {iters: Box::new(iters), body: Box::new(body)})
            .map_with_span(Spanned::new);
        let loop_infinite = just(Token::Loop)
            .then(expr.clone())
            .map(|(_token, body)| Expression::LoopInfinite {body: Box::new(body)})
            .map_with_span(Spanned::new);
        let loop_for =
            just(Token::For).then(var_name.clone()).then(expr.clone()).then(expr.clone()).then(expr.clone()).then(block.clone())
                .map(|(((((_token, var), start), end), step), body)| {
                    return Expression::For { var: var.item, start: Box::new(start), end: Box::new(end), step: Some(Box::new(step)), body: Box::new(body) }
                })
            .or(
                just(Token::For)
                .then(var_name.clone()).then(expr.clone()).then(expr.clone()).then(block.clone())
                .map(|((((_token, var), start), end), body)|{
                    return Expression::For { var: var.item, start: Box::new(start), end: Box::new(end), step: None, body: Box::new(body) }
                })
            )
            .map_with_span(Spanned::new);
        let loop_while = just(Token::While)
            .then(expr.clone())
            .then(expr.clone())
            .map(|((_token, cond), body)| Expression::While {cond: Box::new(cond), body: Box::new(body)})
            .map_with_span(Spanned::new);


        // Structure
        let fndef = just(Token::FnDef)
            .then(select! {Token::Function(x) => x})
            .then(
                (select! {Token::Variable(x) => x}).separated_by(just(Token::Comma))
                .delimited_by(just(Token::LeftParent), just(Token::RightParent)))
            .then(expr.clone())
            .map(|(((_token, name), args), body)|{
                Expression::FnDef { name: name, args: args, body: Box::new(body) }
            })
            .map_with_span(Spanned::new);

        // Atom
        let atom =
            literal
            .or(expr.clone().delimited_by(just(Token::LeftParent), just(Token::RightParent)))
            .or(call)
            .or(assignment)
            .or(condition)
            .or(ret)
            .or(break_expr)
            .or(loop_finite)
            .or(loop_infinite)
            .or(loop_for)
            .or(loop_while)
            .or(fndef)
            .or(shortcall)
            .or(var)
            .or(func)
            .or(objdef);

        // Operators
        let unary = just(Token::Minus)
            .map_with_span(Spanned::new)
            .repeated()
            .then(atom.clone())
            .foldr(|op, rhs| {
                let end = rhs.span.end;
                Spanned::new(Expression::Negation(Box::new(rhs)), Range {start: op.span.start, end: end})
            });

        let product = unary
            .clone()
            .then(
                just(Token::Star)
                    .to(Expression::Multiply as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                .or(
                    just(Token::Slash)
                    .to(Expression::Division as fn(_, _) -> _)
                    .map_with_span(Spanned::new))
                .then(unary)
                .repeated(),
            )
            .foldl(|lhs, (op, rhs)| {
                let start = lhs.span.start;
                let end = rhs.span.end;
                Spanned::new((op.item)(Box::new(lhs), Box::new(rhs)), Range {start: start, end: end})
            });

        let sum = product
            .clone()
            .then(
                just(Token::Plus)
                    .to(Expression::Addition as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                .or(
                    just(Token::Minus).to(Expression::Subtraction as fn(_, _) -> _)
                    .map_with_span(Spanned::new))
                .then(product)
                .repeated(),
            )
            .foldl(|lhs, (op, rhs)| {
                let start = lhs.span.start;
                let end = rhs.span.end;
                Spanned::new((op.item)(Box::new(lhs), Box::new(rhs)), Range {start: start, end: end})
            });

        let eq = sum
            .clone()
            .then(
                just(Token::Eq)
                    .to(Expression::Eq as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                .or(
                    just(Token::Neq).to(Expression::Neq as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                )
                .or(
                    just(Token::Lt).to(Expression::Lt as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                )
                .or(
                    just(Token::Gt).to(Expression::Gt as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                )
                .or(
                    just(Token::Lte).to(Expression::Lte as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                )
                .or(
                    just(Token::Gte).to(Expression::Gte as fn(_, _) -> _)
                    .map_with_span(Spanned::new)
                )
                .then(sum)
                .repeated()
            )
            .foldl(|lhs, (op, rhs)| {
                let start = lhs.span.start;
                let end = rhs.span.end;
                Spanned::new((op.item)(Box::new(lhs), Box::new(rhs)), Range {start: start, end: end})
            });

        eq
        .or(
            block
        )
    });
    expression
        .repeated()
        .map(Expression::Block)
        .map_with_span(|tok, span| Spanned::new(tok, span))
        .then_ignore(end())
}
