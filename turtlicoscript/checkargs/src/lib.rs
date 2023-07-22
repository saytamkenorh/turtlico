use proc_macro2::TokenTree;
use quote::{format_ident, quote};
use syn::{parse_macro_input, ItemFn};

#[derive(Debug)]
struct ArgTypeSpec {
    pub arg_type: String,
    pub default_value: Option<proc_macro2::Literal>,
}

#[derive(PartialEq, Eq)]
enum ParseState {
    Start,
    Identifier,
    Assignment,
}

/// Usage:
/// #[check_args(String, Int=1)]
/// fn your_function(mut args: NativeFuncArgs) -> NativeFuncReturn {
///     do_something(arg0);
///     do_something_other(arg1);
/// }
#[proc_macro_attribute]
pub fn check_args(
    attr: proc_macro::TokenStream,
    input: proc_macro::TokenStream,
) -> proc_macro::TokenStream {
    //println!("{:?}", attr);

    let mut specs = vec![];
    let mut last_spec = None;
    let mut state = ParseState::Start;
    let attr = proc_macro2::TokenStream::from(attr);
    for token in attr {
        match token {
            TokenTree::Ident(i) => {
                assert!(state == ParseState::Start);
                if let Some(spec) = last_spec {
                    specs.push(spec);
                }
                last_spec = Some(ArgTypeSpec {
                    arg_type: i.to_string(),
                    default_value: None,
                });
                state = ParseState::Identifier;
            }
            TokenTree::Punct(p) => {
                assert!(p.as_char() == '=' || p.as_char() == ',');
                if p.as_char() == '=' {
                    assert!(state == ParseState::Identifier);
                    state = ParseState::Assignment;
                }
                if p.as_char() == ',' {
                    state = ParseState::Start;
                }
            }
            TokenTree::Literal(lit) => {
                assert!(state == ParseState::Assignment);
                assert!(last_spec.is_some());
                last_spec.as_mut().unwrap().default_value = Some(lit);
                state = ParseState::Start;
            }
            _ => {
                panic!("Syntax error. Please use <Type> or <Type>=<Default value>")
            }
        }
    }
    if let Some(spec) = last_spec {
        specs.push(spec);
    }

    let mut arg_checker = proc_macro2::TokenStream::new();

    let argc = specs.len();
    // Add defaults
    for (pos, arg) in specs.iter().enumerate() {
        if let Some(default_value) = &arg.default_value {
            let req_argc = pos + 1;
            arg_checker.extend(quote! {
                if args.len() < #req_argc {
                    args.push(Value::from(#default_value));
                }
            });
        }
    }
    // Check argument count
    arg_checker.extend(quote! {
        if args.len() != #argc {
            return Err(RuntimeError::InvalidArgCount(args.len(), #argc));
        }
    });
    // Check argument types
    for (pos, arg) in specs.iter().enumerate() {
        let arg_type = &arg.arg_type;
        let varname = format_ident!("arg{}", pos);
        if arg_type == "String" {
            arg_checker.extend(quote! {
                let mut #varname = None;
                match &args[#pos] {
                    Value::String(val) => {
                        #varname = Some(val);
                    },
                    _ => {
                        return Err(RuntimeError::InvalidArgType(#pos));
                    }
                }
                let #varname = #varname.unwrap();
            });
        } else if arg_type == "Int" {
            arg_checker.extend(quote! {
                let mut #varname = None;
                match args[#pos] {
                    Value::Int(val) => {
                        #varname = Some(val);
                    },
                    _ => {
                        return Err(RuntimeError::InvalidArgType(#pos));
                    }
                }
                let #varname = #varname.unwrap();
            });
        } else if arg_type == "Float" {
            arg_checker.extend(quote! {
                let mut #varname = None;
                match args[#pos] {
                    Value::Int(val) => {
                        #varname = Some(val as f64);
                    },
                    Value::Float(val) => {
                        #varname = Some(val);
                    },
                    _ => {
                        return Err(RuntimeError::InvalidArgType(#pos));
                    }
                }
                let #varname = #varname.unwrap();
            });
        } else if arg_type == "Object" {
            arg_checker.extend(quote! {
                let mut #varname = None;
                match args[#pos].clone() {
                    Value::Object(val) => {
                        #varname = Some(val);
                    },
                    _ => {
                        return Err(RuntimeError::InvalidArgType(#pos));
                    }
                }
                let #varname = #varname.unwrap();
            });
        } else if arg_type == "Other" {
        } else {
            panic!("Checking for type {} is not suppored!", arg_type)
        }
    }
    //println!("{}", arg_checker.to_string());

    let ItemFn {
        attrs,
        vis,
        sig,
        block,
    } = parse_macro_input!(input as ItemFn);
    let stmts = &block.stmts;
    let output = quote! {
        #(#attrs)* #vis #sig {
            #arg_checker
            #(#stmts)*
        }
    };
    output.into()
}
