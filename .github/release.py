import argparse
import requests


def clean_github_release(
    token: str,
    tag: str,
    repo="Genius-Society/rogsoft_cloudreve",
    endpoint="https://api.github.com/repos",
):
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
    }
    # 1. 先判断 tag 是否存在
    tag_url = f"{endpoint}/{repo}/git/refs/tags/{tag}"
    response = requests.get(tag_url, headers=headers)
    if response.status_code == 404:
        print(f"Git tag '{tag}' not found, nothing to delete.")
        return

    response.raise_for_status()
    # 2. 判断 release 是否存在
    releases_url = f"{endpoint}/{repo}/releases"
    response = requests.get(releases_url, headers=headers)
    response.raise_for_status()
    tag_release = None
    releases: list[dict] = response.json()
    for release in releases:
        if release.get("tag_name") == tag:
            tag_release = release
            break

    if tag_release:
        response = requests.delete(
            f"{releases_url}/{tag_release['id']}",
            headers=headers,
        )
        if response.status_code == 204:
            print(f"Successfully deleted release with tag '{tag}'")
        else:
            response.raise_for_status()

    else:
        print(f"No release found with tag '{tag}'. Will delete only the tag.")
    # 3. 删除 tag
    response = requests.delete(tag_url, headers=headers)
    if response.status_code == 204:
        print(f"Successfully deleted Git tag '{tag}'")
    else:
        response.raise_for_status()


def create_github_release(
    token: str,
    tag: str,
    fpath="cloudreve.tar.gz",
    repo="Genius-Society/rogsoft_cloudreve",
):
    response = requests.post(
        f"https://api.github.com/repos/{repo}/releases",
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
        },
        json={
            "tag_name": tag,
            "name": f"v{tag}",
            "body": f"Upd {repo.split('_')[-1].capitalize()} bin to ver {tag}",
            "draft": False,
            "prerelease": False,
        },
    )
    if response.status_code != 201:
        raise ConnectionError(f"{response.status_code}: {response.json()}")
    # Get upload URL
    release: str = response.json()["upload_url"]
    upload_url = release.split("{")[0]
    with open(fpath, "rb") as binary_file:
        upl_response = requests.post(
            f"{upload_url}?name={fpath}",
            headers={
                "Authorization": f"token {token}",
                "Content-Type": "application/octet-stream",
            },
            data=binary_file,
        )

    if upl_response.status_code == 201:
        print(f"Upload '{fpath}' success!")
    else:
        response.raise_for_status()


def release(token: str, tag: str):
    clean_github_release(token, tag)
    create_github_release(token, tag)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auto GitHub release")
    parser.add_argument("--token", required=True, help="Your GitHub Access Token")
    parser.add_argument("--ver", required=True, help="Relase version")
    args = parser.parse_args()
    release(args.token, tag=args.ver)
