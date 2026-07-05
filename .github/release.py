import os
import time
import random
import hashlib
import argparse
import requests


class GitHubReleaseManager:
    def __init__(self, version: str, token: str):
        self.repo = os.getenv("GITHUB_REPOSITORY")
        self.name = self.repo.split("_")[-1].capitalize()
        self.pkg = f"{self.name.lower()}.tar.gz"
        self.endpoint = f"https://api.github.com/repos/{self.repo}"
        self.ver = version
        self.token = token
        self.header = {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
        }
        self.headers = {
            "Authorization": f"token {token}",
            "Content-Type": "application/octet-stream",
        }

    def clean_release(self) -> str:  # 1. 先判断 tag 是否存在
        release_url = f"{self.endpoint}/releases"
        tag_url = f"{self.endpoint}/git/refs/tags/{self.ver}"
        response = requests.get(tag_url, headers=self.header)
        if response.status_code == 404:
            print(f"Tag {self.ver} not found, nothing to delete.")
            return release_url

        response.raise_for_status()  # 2. 判断 release 是否存在
        response = requests.get(release_url, headers=self.header)
        response.raise_for_status()
        tag_release = None
        releases: list[dict] = response.json()
        for release in releases:
            if release.get("tag_name") == self.ver:
                tag_release = release
                break

        if tag_release:
            response = requests.delete(
                f"{release_url}/{tag_release['id']}",
                headers=self.header,
            )
            if response.status_code == 204:
                print(f"Releases with tag {self.ver} have successfully been deleted!")
            else:
                response.raise_for_status()

        else:
            print(f"No release found with tag {self.ver}, only tag will be deleted.")
        # 3. 删除 tag
        response = requests.delete(tag_url, headers=self.header)
        if response.status_code == 204:
            print(f"The tag {self.ver} has successfully been deleted!")
        else:
            response.raise_for_status()

        return release_url

    def create_release(self, release_url: str, md5_txt="md5sum.txt") -> str:
        response = requests.post(
            release_url,
            headers=self.header,
            json={
                "tag_name": self.ver,
                "name": f"v{self.ver}",
                "body": f"Update {self.name} binary to verion {self.ver}",
                "draft": True,
                "prerelease": False,
            },
        )
        if response.status_code != 201:
            response.raise_for_status()
        # Get upload URL
        response_dict: dict = response.json()
        release_id = response_dict["id"]
        upload_url: str = response_dict["upload_url"]
        upl_url = upload_url.split("{")[0]
        with open(self.pkg, "rb") as f:
            response = requests.post(
                f"{upl_url}?name={self.pkg}",
                headers=self.headers,
                data=f,
            )
            md5 = hashlib.md5(f.read()).hexdigest()

        if response.status_code != 201:
            response.raise_for_status()

        with open(md5_txt, "w", encoding="utf-8") as f:
            f.write(md5)

        with open(md5_txt, "rb") as f:
            response = requests.post(
                f"{upl_url}?name={md5_txt}",
                headers=self.headers,
                data=f,
            )

        if response.status_code == 201:
            print(f"{self.pkg} with md5 has successfully been uploaded!")
        else:
            response.raise_for_status()

        return release_id

    def publish_release(self):
        release_url = self.clean_release()
        release_id = self.create_release(release_url)
        response = requests.patch(
            f"{release_url}/{release_id}",
            json={"draft": False},
            headers=self.header,
        )
        response.raise_for_status()
        print(f"🎉 {self.name} release has been published!")
        return release_id

    def check_release(self):
        try:
            response = requests.get(f"{self.endpoint}/releases/tags/{self.ver}")
            response.raise_for_status()
            return True

        except Exception:
            return False

    def release(self):
        self.publish_release()
        while not self.check_release():
            self.publish_release()
            time.sleep(random.randint(3, 7))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auto GitHub release")
    parser.add_argument("--ver", required=True, help="Release version")
    parser.add_argument("--token", required=True, help="Your GitHub Access Token")
    args = parser.parse_args()
    GitHubReleaseManager(args.ver, args.token).release()
