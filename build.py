import os
import json
import hashlib
import subprocess

parent_path = os.path.dirname(os.path.realpath(__file__))


def md5sum(full_path):
    with open(full_path, "rb") as rf:
        return hashlib.md5(rf.read()).hexdigest()


def get_or_create():
    conf_path = os.path.join(parent_path, "config.json")
    conf = {}
    if not os.path.isfile(conf_path):
        print("config.json not found, build.py is root path. auto write config.json")
        module_name = os.path.basename(parent_path)
        conf["module"] = module_name
        conf["version"] = "0.1"
        conf["home_url"] = "Module_%s.asp" % module_name
        conf["title"] = "title of " + module_name
        conf["description"] = "description of " + module_name

    else:
        with open(conf_path, "r", encoding="utf-8") as fc:
            conf = json.loads(fc.read())

    return conf


def pack_folder(module_name: str):
    subprocess.run(["7z", "a", "-ttar", f"{module_name}.tar", module_name], check=True)
    subprocess.run(
        ["7z", "a", "-tgzip", f"{module_name}.tar.gz", f"{module_name}.tar"],
        check=True,
    )
    if os.path.exists(f"{module_name}.tar"):
        os.remove(f"{module_name}.tar")
    else:
        print(f"Failed to create {module_name}.tar")


def fix_crlf():
    sh_script = os.path.dirname(os.path.abspath(__file__)) + "\\rm_crlf.sh"
    subprocess.run(["bash", sh_script], check=True)


def build_module():
    try:
        fix_crlf()
        conf = get_or_create()

    except Exception as e:
        print(f"config.json file format is incorrect: {e}")

    if "module" not in conf:
        print(" module is not in config.json")
        return

    module_path = os.path.join(parent_path, conf["module"])
    if not os.path.isdir(module_path):
        print("not found %s dir, check config.json is module ?" % module_path)
        return

    install_path = os.path.join(parent_path, conf["module"], "install.sh")
    if not os.path.isfile(install_path):
        print("not found %s file, check install.sh file")
        return

    print("build...")
    open(parent_path + "/" + conf["module"] + "/" + "version", "w").write(
        conf["version"]
    )
    pack_folder(conf["module"])
    conf["md5"] = md5sum(os.path.join(parent_path, conf["module"] + ".tar.gz"))
    conf_path = os.path.join(parent_path, "config.json")
    with open(conf_path, "w", encoding="utf-8") as fw:
        json.dump(conf, fw, sort_keys=True, indent=4, ensure_ascii=False)

    print("build done", conf["module"] + ".tar.gz")


if __name__ == "__main__":
    build_module()
