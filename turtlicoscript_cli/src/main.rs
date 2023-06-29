use std::{env, fs};
use turtlicoscript::{parser};
use turtlicoscript::ast::{Spanned, Expression};

#[cfg(feature = "gui")]
fn run(ast: Spanned<Expression>) {
    let subapp = turtlicoscript_gui::app::ScriptApp::spawn(ast, false);
    turtlicoscript_gui::app::RootApp::run(vec![
        subapp
    ]);
}

#[cfg(not(feature = "gui"))]
fn run(ast: Spanned<Expression>) {
    use {interpreter::Context, value::Value};
    let mut ctx = Context::new_parent();
    match context.eval_root(&ast) {
        Ok(val) => {
            if !gui {
                match val {
                    Value::Int(retcode) => std::process::exit(retcode.try_into().unwrap_or(-1)),
                    _ => std::process::exit(0),
                }
            }
        },
        Err(err) => {
            eprintln!("{}", err.build_message(&src));
        }
    }
}

fn main() {
    let file = env::args().nth(1).expect("Expected file argument");
    run_file(file);
}

fn run_file(file: String) {
    let src = fs::read_to_string(file)
        .expect("Failed to read file");

    println!("Tokens:");
    for token in parser::get_tokens(&src) {
        println!("{:?}", token);
    }

    match parser::parse(&src) {
        Ok(ast) => {
            run(ast);
        },
        Err(errors) => {
            eprintln!("File parse error (s):\n{}", errors.into_iter().map(|err| err.build_message(&src)).collect::<Vec<String>>().join("\n"));
        }
    }
}
