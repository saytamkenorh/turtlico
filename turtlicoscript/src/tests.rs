
#[cfg(test)]
mod test_examples {
    use std::{env, path, fs};

    use crate::{parser, interpreter};

    #[test]
    fn binops() {
        test_example_file("binops.tcsf", "5.1_8_12_7_7");
    }

    #[test]
    fn loop_for() {
        test_example_file("for.tcsf", "0_1_2_3_4_5_6_7_8_9_10_0_2_4_6_8_10_");
    }

    #[test]
    fn funcs() {
        test_example_file("funcs.tcsf", "7_5_3_");
    }

    #[test]
    fn objects() {
        test_example_file("objects.tcsf", "1_text_value_text_inserted");
    }

    #[test]
    fn padding() {
        test_example_file("padding.tcsf", "111");
    }


    #[test]
    fn loop_while() {
        test_example_file("while.tcsf", "5_4_3_2_1_0_");
    }

    fn test_example_file(name: &str, output: &str) {
        let root_dir = &env::var("CARGO_MANIFEST_DIR").expect("$CARGO_MANIFEST_DIR");
        let mut path_buf = path::PathBuf::new();
        path_buf.push(root_dir);
        path_buf.pop();
        path_buf.push("tests");
        path_buf.push(name);
        println!("{}", path_buf.display());
        let src = fs::read_to_string(path_buf).expect(&format!("Cannot read example file \"{}\"", name));
        let ast = parser::parse(&src).expect(&format!("Cannot parse example file \"{}\"", name));

        let mut context = interpreter::Context::new_parent(None);
        let _result = context.eval_root(&ast).expect(&format!("Evaluation of example file failed \"{}\"", name)).to_string();
        if output != _result {
            panic!("Invalid result. Expected: \"{}\". Got: \"{}\".", output, _result);
        }
    }
}