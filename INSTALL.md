# Installing ULink CLI

## Option 1: Install to /usr/local/bin (Recommended)

This makes the CLI available system-wide:

```bash
cd ulink_cli
sudo cp ulink /usr/local/bin/
sudo chmod +x /usr/local/bin/ulink
```

Then you can use it from anywhere:
```bash
ulink login
ulink verify
```

## Option 2: Install to ~/bin (User-specific)

If you prefer not to use sudo:

```bash
# Create ~/bin if it doesn't exist
mkdir -p ~/bin

# Copy the executable
cp ulink_cli/ulink ~/bin/

# Make it executable
chmod +x ~/bin/ulink

# Add ~/bin to PATH (add this to your ~/.zshrc or ~/.bash_profile)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc

# Reload your shell
source ~/.zshrc
```

## Option 3: Add Current Directory to PATH

If you want to keep the executable in the project directory:

```bash
# Add to ~/.zshrc (for zsh) or ~/.bash_profile (for bash)
echo 'export PATH="$PATH:/Users/mohn93/Desktop/all_ulink/ulink_cli"' >> ~/.zshrc

# Reload your shell
source ~/.zshrc
```

## Option 4: Create a Symlink

Create a symlink in a directory already in your PATH:

```bash
# For /usr/local/bin (requires sudo)
sudo ln -s /Users/mohn93/Desktop/all_ulink/ulink_cli/ulink /usr/local/bin/ulink

# Or for ~/bin (no sudo needed)
mkdir -p ~/bin
ln -s /Users/mohn93/Desktop/all_ulink/ulink_cli/ulink ~/bin/ulink
```

## Verify Installation

After installation, verify it works:

```bash
ulink --help
```

You should see the help message with all available commands.

## Uninstall

To remove the CLI:

```bash
# If installed to /usr/local/bin
sudo rm /usr/local/bin/ulink

# If installed to ~/bin
rm ~/bin/ulink

# If using symlink
rm /usr/local/bin/ulink  # or ~/bin/ulink
```
