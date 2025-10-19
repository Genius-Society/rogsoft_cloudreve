import os
import re
import json
import hashlib
import tarfile
import subprocess
import urllib.request
from pathlib import Path


def latest_release(repo):
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    headers = {}
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        data = json.load(resp)

    ver = data["tag_name"]
    return ver, f"https://github.com/{repo}/releases/download/{ver}"


def remote_sha256(ver: str, url: str):
    txt = urllib.request.urlopen(f"{url}/checksums.txt").read().decode()
    return re.search(
        rf"^([a-f0-9]{{64}})\s+cloudreve_{ver}_darwin_arm64\.tar\.gz$",
        txt,
        re.M,
    ).group(1)


def local_sha256(fpath: str):
    h = hashlib.sha256()
    with Path(fpath).open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)

    return h.hexdigest()


def verify(fpath: str, sha256: str):
    print("\n校验 SHA256 ...")
    if local_sha256(fpath) != sha256:
        raise RuntimeError("SHA256 校验失败，文件可能被篡改")

    print("SHA256 校验通过")


def download(ver: str, url: str, dld_to: str, sha256: str):
    dld_file = Path(dld_to)
    if dld_file.exists() and local_sha256(dld_file) == sha256:
        print("本地文件已存在且校验通过，跳过下载")
        return dld_to

    print("正在下载 ...")
    os.makedirs(os.path.dirname(dld_to), exist_ok=True)
    urllib.request.urlretrieve(
        f"{url}/cloudreve_{ver}_darwin_arm64.tar.gz",
        dld_file,
        reporthook=lambda b, bsize, tsize: print(
            f"\r{b * bsize / 1024 / 1024:.1f} MB / {tsize / 1024 / 1024:.1f} MB",
            end="",
            flush=True,
        ),
    )
    verify(dld_to, sha256)
    return dld_to


def extract(fpath: str, extracto: str):
    extract_dir = Path(extracto)
    extract_dir.mkdir(exist_ok=True)
    with tarfile.open(Path(fpath), "r:gz") as tar:
        tar.extractall(extract_dir)

    print(f"解压完成，文件位于 {extract_dir.absolute()}")


def rm_cr():
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


def release(proj_name="cloudreve"):
    try:
        ver, url = latest_release("cloudreve/cloudreve")
        sha256 = remote_sha256(ver, url)
        tar = download(ver, url, f"./__pycache__/{sha256}.tar.gz", sha256)
        extract(tar, "./__pycache__")
        os.rename(f"./__pycache__/{proj_name}", f"./{proj_name}/bin/{proj_name}")
        with open(f"./{proj_name}/version", "w", encoding="utf-8") as f:
            f.write(ver)

        rm_cr()
        pack(proj_name)

    except Exception as e:
        print(f"打包出错: {e}")


if __name__ == "__main__":
    release()
