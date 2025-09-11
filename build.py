import os
import json
import hashlib
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


def md5sum(fpath: str):
    with open(fpath, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


def build(conf_path=f"./config.json"):
    try:
        CRLF2LF()
        with open(conf_path, "r", encoding="utf-8") as f:
            conf = json.loads(f.read())

        open(f"./{conf['module']}/version", "w").write(conf["version"])
        output = pack(conf["module"])
        conf["md5"] = md5sum(output)
        with open(conf_path, "w", encoding="utf-8") as f:
            json.dump(conf, f, indent=4, sort_keys=True, ensure_ascii=False)

        print(f"{conf_path} 已更新")

    except Exception as e:
        print(f"打包出错: {e}")


if __name__ == "__main__":
    build()
