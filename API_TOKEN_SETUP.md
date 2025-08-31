# Gitea API Token Setup for Automated Releases

The SoulBox project uses automated Gitea releases through the smart versioning system. To enable full release functionality including asset uploads, you need to configure a Gitea API token.

## Setting Up the API Token

### 1. Generate Gitea Personal Access Token

1. Log into your Gitea server: http://192.168.176.113:3000
2. Go to **Settings** → **Applications** → **Generate New Token**
3. Enter a token name: `SoulBox Build Automation`
4. Select required permissions:
   - `repo`: Full repository access
   - `write:repository`: Repository write access
   - `write:issue`: Issue management (for release notes)
5. Click **Generate Token**
6. **Copy the token immediately** (you won't be able to see it again!)

### 2. Configure Token in Build Environment

#### For Gitea Actions (Current Setup)
Since we're using Gitea's own runner, you can set the token as a secret:

1. In your Gitea repository, go to **Settings** → **Secrets**
2. Add a new secret:
   - **Name**: `GITOKEN`
   - **Value**: Your copied API token
3. The workflow will automatically use this token

#### For Local Testing
```bash
export GITOKEN="your_token_here"
./scripts/gitea-version-manager.sh create-release v1.0.0 image.img image.sha256
```

## What the Token Enables

### With Token:
- ✅ Create Gitea releases automatically
- ✅ Upload `.img` files as release assets
- ✅ Upload `.sha256` checksum files
- ✅ Full automated release pipeline

### Without Token:
- ⚠️  Releases creation will fail with "token is required" error
- ⚠️  Build will succeed but no automatic release will be created
- ⚠️  Manual release creation required

## Verifying Token Setup

Test the token manually:
```bash
export GITOKEN="your_token"
curl -H "Authorization: token $GITOKEN" \
     http://192.168.176.113:3000/api/v1/repos/reaper/soulbox/releases
```

You should see a JSON response with your releases.

## Security Notes

- Never commit API tokens to the repository
- Use environment variables or secrets management
- The token provides full repository access - keep it secure
- Consider using a dedicated service account for automation

## Troubleshooting

### "token is required" Error
- The `GITOKEN` environment variable is not set
- Token may be expired or invalid
- Check token permissions in Gitea settings

### Asset Upload Failures  
- Token lacks `write:repository` permissions
- File paths are incorrect in the build script
- Network connectivity issues to Gitea server

### Release Creation Succeeds but No Assets
- Token is valid but upload permissions missing
- File size limitations (check Gitea configuration)
- API endpoint changes (verify Gitea version compatibility)

---

🌟 With proper token setup, your SoulBox builds will automatically create GitHub-style releases with downloadable assets! 🔥
