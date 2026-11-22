#!/usr/bin/env python3
"""增量发布到 GitHub（仅通过 API，用于 git over HTTPS 不可用的环境）。

用法：
    GH_TOKEN=<fine-grained token, Contents: RW> python3 tool/publish.py "提交说明"

原理：
    1. 读取远端 main 的文件树
    2. 与本地 git index 比对，只上传内容变化的 blob
    3. 以远端树为 base_tree 生成新树（含删除项）
    4. 创建新提交 -> 快进更新 main
"""
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

OWNER, REPO = 'wangxi3709', 'Glimpse'
API = 'https://api.github.com'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN = os.environ.get('GH_TOKEN', '')


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_opener = urllib.request.build_opener(_NoRedirect)


def req(method, url, data=None, raw=None, ctype='application/json', depth=0):
    body = json.dumps(data).encode() if data is not None else raw
    r = urllib.request.Request(url, data=body, method=method)
    r.add_header('Authorization', f'Bearer {TOKEN}')
    r.add_header('Accept', 'application/vnd.github+json')
    r.add_header('X-GitHub-Api-Version', '2022-11-28')
    if body is not None:
        r.add_header('Content-Type', ctype)
    try:
        with _opener.open(r, timeout=120) as resp:
            return resp.status, json.loads(resp.read().decode() or '{}')
    except urllib.error.HTTPError as e:
        loc = e.headers.get('Location')
        if e.code in (301, 302, 307, 308) and loc and depth < 5:
            return req(method, loc, data, raw, ctype, depth + 1)
        if e.code == 404 and method == 'GET':
            return 404, {}
        print(f'  ! {method} {url} -> {e.code}: {e.read().decode()[:160]}',
              file=sys.stderr)
        return e.code, {}


def local_index():
    """返回 {path: (mode, blob_sha)}，来自 git index（先 git add -A）"""
    out = subprocess.run(['git', 'ls-files', '-s', '-z'], cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout
    files = {}
    for entry in out.split('\0'):
        if not entry:
            continue
        meta, path = entry.split('\t', 1)
        parts = meta.split()
        files[path] = (parts[0], parts[1])
    return files


def remote_tree(sha):
    code, data = req('GET', f'{API}/repos/{OWNER}/{REPO}/git/trees/{sha}?recursive=1')
    if code != 200:
        return {}, {}
    blobs = {t['path']: t['sha'] for t in data.get('tree', []) if t['type'] == 'blob'}
    return blobs, data


def main():
    if not TOKEN:
        sys.exit('缺少 GH_TOKEN 环境变量')

    message = sys.argv[1] if len(sys.argv) > 1 else 'update'
    subprocess.run(['git', 'add', '-A'], cwd=ROOT, check=True)
    files = local_index()

    code, ref = req('GET', f'{API}/repos/{OWNER}/{REPO}/git/ref/heads/main')
    base_sha = ref['object']['sha'] if code == 200 else None

    remote = {}
    if base_sha:
        remote, tree_data = remote_tree(base_sha)
        remote_tree_sha = tree_data.get('sha') if tree_data else None
    else:
        remote_tree_sha = None

    changed = [(p, m, s) for p, (m, s) in files.items() if remote.get(p) != s]
    deleted = [p for p in remote if p not in files]
    print(f'本地 {len(files)} 个文件，变更 {len(changed)}，删除 {len(deleted)}')
    if not changed and not deleted:
        print('没有变化，无需发布')
        return

    items = []
    for path, mode, sha in changed:
        data = open(os.path.join(ROOT, path), 'rb').read()
        code, out = req('POST', f'{API}/repos/{OWNER}/{REPO}/git/blobs',
                        {'content': base64.b64encode(data).decode(),
                         'encoding': 'base64'})
        if code not in (200, 201):
            sys.exit(f'上传 {path} 失败: {code}')
        items.append({'path': path,
                      'mode': '100755' if mode == '100755' else '100644',
                      'type': 'blob', 'sha': out['sha']})
    for path in deleted:
        items.append({'path': path, 'mode': '100644', 'type': 'blob', 'sha': None})

    payload = {'tree': items}
    if remote_tree_sha:
        payload['base_tree'] = remote_tree_sha
    code, out = req('POST', f'{API}/repos/{OWNER}/{REPO}/git/trees', payload)
    if code not in (200, 201):
        sys.exit(f'创建树失败: {code}')
    new_tree = out['sha']

    payload = {'message': message, 'tree': new_tree}
    if base_sha:
        payload['parents'] = [base_sha]
    code, out = req('POST', f'{API}/repos/{OWNER}/{REPO}/git/commits', payload)
    if code not in (200, 201):
        sys.exit(f'创建提交失败: {code}')
    commit = out['sha']

    if base_sha:
        code, _ = req('PATCH', f'{API}/repos/{OWNER}/{REPO}/git/refs/heads/main',
                      {'sha': commit})
    else:
        code, _ = req('POST', f'{API}/repos/{OWNER}/{REPO}/git/refs',
                      {'ref': 'refs/heads/main', 'sha': commit})
    print(f'已发布 {commit[:8]}  ({len(changed)} 改 / {len(deleted)} 删)')


if __name__ == '__main__':
    main()
