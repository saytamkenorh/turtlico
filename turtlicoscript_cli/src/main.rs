use std::collections::HashMap;
use std::{env, fs};
use turtlicoscript::parser;
use turtlicoscript::ast::{Spanned, Expression};
use turtlicoscript_gui::{app::ScriptState, world::WorldCreationData};

#[cfg(feature = "gui")]
fn run(ast: Spanned<Expression>, src: &String, data: WorldCreationData) {
    let subapp = turtlicoscript_gui::app::ScriptApp::spawn(ast, data, false);
    let state = subapp.program_state.clone();

    turtlicoscript_gui::app::RootApp::run(
        |_ctx|{ vec![
            Box::new(subapp)
        ]}
    );
    let _state = state.lock().unwrap();
    match &*_state {
        ScriptState::Error(err) => {
            eprintln!("{}", err.build_message(&src));
        }
        _ => {}
    }
}

#[cfg(not(feature = "gui"))]
fn run(ast: Spanned<Expression>, src: &String, data: WorldCreationData) {
    todo!();
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
    let src = fs::read_to_string(file.to_owned())
        .expect("Failed to read file");
    let script_dir = std::path::Path::new(&file.to_owned()).parent().map(|p| p.to_str().unwrap().to_owned());

    println!("Tokens:");
    for token in parser::get_tokens(&src) {
        println!("{:?}", token);
    }

    match parser::parse(&src) {
        Ok(ast) => {
            println!("AST:");
            println!("{:#?}", ast);
            let data = WorldCreationData {
                tilemaps: HashMap::new(),
                script_dir
            };
            run(ast, &src, data);
        },
        Err(errors) => {
            eprintln!("File parse error (s):\n{}", errors.into_iter().map(|err| err.build_message(&src)).collect::<Vec<String>>().join("\n"));
        }
    }
}
