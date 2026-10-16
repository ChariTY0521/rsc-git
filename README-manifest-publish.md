# 发布签名清单

将 `publish-manifest.bat` 或 `publish-manifest.sh` 复制到 `rsc-git` 根目录，并与以下文件放在一起：

- `rustdesk.json`
- `rsc-manifest-private.pem`
- `rsc-manifest-public.pem`
- `.gitattributes`

Windows 运行 `publish-manifest.bat`；Linux/macOS 运行 `chmod +x publish-manifest.sh && ./publish-manifest.sh`。

脚本会规范化并暂存 JSON、签名暂存的原始字节、验证签名，然后提交和推送到 `main`。私钥不会被加入 Git。

`.gitattributes` 必须包含：

```gitattributes
rustdesk.json text eol=lf
rustdesk.json.sig -text
```
