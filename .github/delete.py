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
            f"{releases_url}/{tag_release['id']}", headers=headers
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auto GitHub release")
    parser.add_argument("--token", required=True, help="Your GitHub Access Token")
    parser.add_argument("--ver", required=True, help="Relase version")
    args = parser.parse_args()
    clean_github_release(args.token, tag=args.ver)
