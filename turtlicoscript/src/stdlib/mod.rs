use std::any::Any;
use std::io::Write;

use crate::error::RuntimeError;
use crate::interpreter::Scope;
use crate::value::{Value, NativeFuncArgs, NativeFuncReturn, Library, LibraryContext, NativeFuncCtxArg, FuncThisObject};
use crate::{funcmap, check_argc};
use checkargs::check_args;
use rand::Rng;

pub mod io;

struct Context {

}
impl LibraryContext for Context {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

pub fn init_library() -> Library {
    let mut scope = Scope::new();
    scope.vars.extend(funcmap!{"std",
        println,
        print,
        readln,
        int,
        float,
        string,
        random
    });
    let ctx = Context {};
    Library {
        name: "std".to_owned(),
        scope: scope,
        context: Box::new(ctx)
    }
}

pub fn println(_ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn{
    println!("{}", args.into_iter().map(|val| val.to_string()).collect::<Vec<String>>().join(" "));
    Ok(Value::None)
}

pub fn print(_ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn{
    print!("{}", args.into_iter().map(|val| val.to_string()).collect::<Vec<String>>().join(" "));
    Ok(Value::None)
}

///Reads line from input
#[check_args(String="")]
pub fn readln(_ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    if !arg0.is_empty() {
        print!("{}", arg0);
    }

    std::io::stdout().flush().unwrap();

    let mut buffer = String::new();
    let stdin = std::io::stdin();
    stdin.read_line(&mut buffer).map_err(|err| RuntimeError::NativeLibraryError(err.to_string()))?;
    buffer = buffer.trim_end_matches("\n").into();
    Ok(Value::String(buffer))
}

pub fn int(_ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    check_argc!(args, 1);
    let value = args.remove(0);
    match value {
        Value::Int(_) => Ok(value),
        Value::String(val) => val.parse::<i32>()
            .map_err(|err| RuntimeError::TypeParseError(err.to_string()))
            .map(|val| Value::Int(val)),
        _ => {
            Err(RuntimeError::TypeParseUnsupported(value.type_to_string().to_owned(), "int".to_owned()))
        }
    }
}

pub fn float(_ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    check_argc!(args, 1);
    let value = args.remove(0);
    match value {
        Value::Int(_) => Ok(value),
        Value::String(val) => val.parse::<f64>()
            .map_err(|err| RuntimeError::TypeParseError(err.to_string()))
            .map(|val| Value::Float(val)),
        _ => {
            Err(RuntimeError::TypeParseUnsupported(value.type_to_string().to_owned(), "float".to_owned()))
        }
    }
}

pub fn string(_ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    check_argc!(args, 1);
    let value = args.remove(0);
    Ok(Value::String(value.to_string()))
}

pub fn random(_ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    match args.len() {
        0 => {
            Ok(Value::Float(rand::random::<f64>()))
        },
        2 => {
            let min = args.remove(0).try_into()?;
            let max = args.remove(0).try_into()?;
            Ok(Value::Int(rand::thread_rng().gen_range(min..=max)))
        },
        _ => {
            Err(crate::error::RuntimeError::InvalidArgCount(args.len(), 2))
        }
    }
}