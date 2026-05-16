import os
import argparse
import requests


def create_github_release(
    token: str,
    tag: str,
    fpath="./cloudreve.tar.gz",
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
            "body": f"Update {repo.split('_')[-1].capitalize()} binary to version {tag}",
            "draft": False,
            "prerelease": False,
        },
    )
    if response.status_code != 201:
        raise ConnectionError(f"{response.status_code}: {response.json()}")
    # Get upload URL
    release = response.json()
    upload_url = release["upload_url"].split("{")[0]
    fname = os.path.basename(fpath)
    with open(fpath, "rb") as binary_file:
        upl_response = requests.post(
            f"{upload_url}?name={fname}",
            headers={
                "Authorization": f"token {token}",
                "Content-Type": "application/octet-stream",
            },
            data=binary_file,
        )

    if upl_response.status_code == 201:
        print(f"Upload '{fname}' success!")
    else:
        print(f"Failed to upload {fname}: {upl_response.text}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auto GitHub release")
    parser.add_argument("--token", required=True, help="Your GitHub Access Token")
    parser.add_argument("--ver", required=True, help="Relase version")
    args = parser.parse_args()
    create_github_release(args.token, tag=args.ver)
