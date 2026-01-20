# Adding a Custom Icon to Your Installer

## Quick Start

1. **Get your logo as a `.ico` file**
2. **Name it `InterWorks-Logo.ico`** (or update the build script with your filename)
3. **Place it in the same directory as the build script** (`c:\Users\acewi\Desktop\CCInstaller\`)
4. **Run the build script** - the icon will be automatically included

## Creating an ICO File

### Option 1: Online Conversion (Easiest)

1. Go to https://convertio.co/png-ico/ or https://www.icoconverter.com/
2. Upload your company logo (PNG, JPG, or SVG)
3. Select these sizes for best results:
   - 16x16 (small icons)
   - 32x32 (standard)
   - 48x48 (Windows Explorer)
   - 256x256 (large icons)
4. Download the `.ico` file
5. Save it as `InterWorks-Logo.ico` in the installer directory

### Option 2: Using GIMP (Free Desktop Tool)

1. Download GIMP from https://www.gimp.org/
2. Open your logo in GIMP
3. Scale it to 256x256: `Image → Scale Image`
4. Export as ICO: `File → Export As`
5. Choose `.ico` as the file type
6. Save as `InterWorks-Logo.ico`

### Option 3: Using PowerShell (Automated)

If you have a PNG file, you can use this PowerShell script to convert it:

```powershell
# Install required module (one-time)
Install-Module -Name PsIcons -Scope CurrentUser

# Convert PNG to ICO
Import-Module PsIcons
ConvertTo-Icon -Path ".\logo.png" -Destination ".\InterWorks-Logo.ico" -Sizes 16,32,48,256
```

### Option 4: Using ImageMagick (Advanced)

```bash
# Install ImageMagick first
# Then run:
magick convert logo.png -define icon:auto-resize=256,128,64,48,32,16 InterWorks-Logo.ico
```

## Icon Requirements

- **Format**: Must be `.ico` (not PNG, JPG, or other formats)
- **Recommended sizes**: Include multiple sizes in one ICO file for best results
  - 16x16 - Taskbar and window title bars
  - 32x32 - Standard desktop icons
  - 48x48 - Windows Explorer
  - 256x256 - Large icons and high-DPI displays
- **File size**: Keep under 1MB (typically 50-200KB is fine)
- **Transparency**: Supported and recommended for best appearance

## Using Your Icon

### Method 1: Default Name (Recommended)

Save your icon as `InterWorks-Logo.ico` in the installer directory, then build:

```powershell
.\Build-Installer.ps1
```

The build script will automatically find and use it.

### Method 2: Custom Name/Path

If your icon has a different name or location:

```powershell
.\Build-Installer.ps1 -IconFile ".\path\to\your-logo.ico"
```

Or update the default in [Build-Installer.ps1](Build-Installer.ps1):

```powershell
param(
    [string]$IconFile = ".\YourCustomName.ico"
)
```

## Verification

After building, you can verify the icon was applied:

1. Navigate to the `.\build` directory
2. Look at `ClaudeCodeInstaller.exe` in Windows Explorer
3. You should see your custom icon instead of the default PowerShell icon

## Troubleshooting

### Icon doesn't appear

**Problem**: The EXE still has the default PowerShell icon

**Solutions**:
1. Verify the ICO file exists: `Test-Path .\InterWorks-Logo.ico`
2. Check the build output for warnings about the icon file
3. Refresh the Explorer view: Right-click → Refresh
4. Clear the icon cache:
   ```powershell
   ie4uinit.exe -ClearIconCache
   taskkill /IM explorer.exe /F
   start explorer.exe
   ```

### Icon looks blurry

**Problem**: Icon appears pixelated or low-quality

**Solutions**:
- Make sure your source image is at least 256x256 pixels
- Include multiple sizes in the ICO file (16, 32, 48, 256)
- Use a vector format (SVG) as your source if possible
- Ensure the ICO file contains high-quality versions

### "Icon file not found" error

**Problem**: Build script can't find the icon file

**Solutions**:
1. Check the filename matches exactly (case-sensitive on some systems)
2. Verify the file is in the correct directory: `Get-ChildItem *.ico`
3. Use an absolute path: `.\Build-Installer.ps1 -IconFile "C:\full\path\to\icon.ico"`

## Example Icon Locations

Your directory structure should look like this:

```
C:\Users\acewi\Desktop\CCInstaller\
├── Build-Installer.ps1
├── Install-ClaudeCode.ps1
├── InterWorks-Logo.ico          ← Your icon file here
├── README.md
└── build\
    └── ClaudeCodeInstaller.exe  ← Will have your icon
```

## Where the Icon Appears

Once applied, your custom icon will be visible in:

- ✅ Windows Explorer file listings
- ✅ Desktop shortcuts
- ✅ Taskbar when the installer is running
- ✅ Windows "Open With" dialog
- ✅ Task Manager
- ✅ File properties dialog
- ✅ Email attachments
- ✅ Download folders

## Tips for Best Results

1. **Use a simple, recognizable logo**: Complex designs don't scale well to 16x16
2. **High contrast**: Ensure the logo is visible at small sizes
3. **Test at multiple sizes**: View the ICO at 16x16, 32x32, and 256x256 before building
4. **Include transparency**: Makes the icon look professional on any background
5. **Use your brand colors**: Match your company's visual identity

## Free Tools for Icon Creation

- **Online**:
  - https://www.icoconverter.com/
  - https://convertio.co/png-ico/
  - https://favicon.io/

- **Desktop**:
  - GIMP (Free, open-source)
  - Paint.NET (Free, Windows)
  - IcoFX (Free version available)

- **Professional**:
  - Adobe Photoshop
  - Adobe Illustrator
  - Affinity Designer

## Need Help?

If you have trouble creating the icon:
1. Check if your graphic design team has the logo in ICO format already
2. Ask your marketing department for high-resolution logo files
3. Use one of the online converters listed above
4. The installer works fine without a custom icon - it's just a nice-to-have!
