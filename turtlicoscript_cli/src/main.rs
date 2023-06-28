use std::{env, fs};
use turtlicoscript::{parser, interpreter::Context, value::Value};

#[cfg(feature = "gui")]
fn run(file: String) {
    let subapp = turtlicoscript_gui::init_subapp(move |ctx, gui| {
        run_file(file, ctx, gui);
    }, false);
    turtlicoscript_gui::app::RootApp::run(vec![
        subapp
    ]);
}

#[cfg(not(feature = "gui"))]
fn run(file: String) {
    let mut ctx = Context::new_parent();
    run_file(file, ctx, false);
}

fn main() {
    let file = env::args().nth(1).expect("Expected file argument");
    run(file);
}

fn run_file(file: String, mut context: Context, gui: bool) {
    let src = fs::read_to_string(file)
        .expect("Failed to read file");

    println!("Tokens:");
    for token in parser::get_tokens(&src) {
        println!("{:?}", token);
    }

    match parser::parse(&src) {
        Ok(ast) => {
            println!("AST:");
            println!("{:#?}", ast);
            println!("Default context:");
            println!("{:#?}", context.vars);

            println!("Starting interpretation:");
            match context.eval_root(&ast) {
                Ok(val) => {
                    println!("Return value: {}", val);
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
        },
        Err(errors) => {
            eprintln!("File parse error (s):\n{}", errors.into_iter().map(|err| err.build_message(&src)).collect::<Vec<String>>().join("\n"));
        }
    }
}
