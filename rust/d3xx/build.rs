use std::env;

fn main() {
    // Windows環境の場合のみ、ライブラリの検索パスを処理する
    if env::var("CARGO_CFG_TARGET_OS").unwrap() == "windows" {
        // ユーザーが指定した環境変数をチェック
        if env::var("CARGO_FEATURE_STATIC_LINK").is_ok() {
            match env::var("FTD3XX_X64_STATIC_LIB_DIR") {
                Ok(dir) => {
                    // 環境変数が見つかったら、そのパスをCargoの検索パスに追加
                    println!("cargo:rustc-link-search=normal={}", dir);
                    println!("cargo:rustc-link-lib=static=FTD3XXWU");
                }
                Err(_) => {
                    // 環境変数が設定されていない場合、ビルドを失敗させて親切なエラーを出す
                    panic!(
                        "\n\n\
                        =======================================================================\n\
                        [Error] Windows build requires the 'FTD3XXWU.lib' library.\n\
                        Please set the environment variable 'FTD3XX_X64_LIB_DIR' to the directory\n\
                        containing 'FTD3XXWU.lib' and try again.\n\n\
                        Example (PowerShell):\n\
                        $env:FTD3XX_X64_LIB_DIR = \"C:\\path\\to\\ftdi\\library\"\n\
                        =======================================================================\n\
                        "
                    );
                }
            }
        } else {
            match env::var("FTD3XX_X64_DYNAMIC_LIB_DIR") {
                Ok(dir) => {
                    // 環境変数が見つかったら、そのパスをCargoの検索パスに追加
                    println!("cargo:rustc-link-search=normal={}", dir);
                }
                Err(_) => {
                    // 環境変数が設定されていない場合、ビルドを失敗させて親切なエラーを出す
                    panic!(
                        "\n\n\
                        =======================================================================\n\
                        [Error] Windows build requires the 'FTD3XXWU.dll' library.\n\
                        Please set the environment variable 'FTD3XX_X64_DYNAMIC_LIB_DIR' to the directory\n\
                        containing 'FTD3XXWU.dll' and try again.\n\n\
                        Example (PowerShell):\n\
                        $env:FTD3XX_X64_DYNAMIC_LIB_DIR = \"C:\\path\\to\\ftdi\\library\"\n\
                        =======================================================================\n\
                        "
                    );
                }
            }
        }
    }
}
