import os
import subprocess


def CRLF2LF():
    print("CRLF 转 LF")
    subprocess.run(
        [
            "bash",
            "-c",
            "find './' -type f -name '*.sh' -exec sed -i 's/\r$//' {} \;",
        ],
        check=True,
    )


def pack(module_name: str):
    print("打包中...")
    output = f"{module_name}.tar.gz"
    intermediate = f"{module_name}.tar"
    subprocess.run(["7z", "a", "-ttar", intermediate, module_name], check=True)
    subprocess.run(["7z", "a", "-tgzip", output, intermediate], check=True)
    if os.path.exists(intermediate):
        os.remove(intermediate)
    else:
        raise FileNotFoundError(f"生成中间产物 {intermediate} 出错!")

    print(f"打包完成, 输出 {output}")
    return f"./{output}"


if __name__ == "__main__":
    try:
        CRLF2LF()
        pack("cloudreve")

    except Exception as e:
        print(f"打包出错: {e}")
