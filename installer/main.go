package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"
)

// --- main function ---

func main() {
	fmt.Println("Starting dotfiles installer...")

	if err := installDependencies(); err != nil {
		fmt.Fprintf(os.Stderr, "Error installing dependencies: %v\n", err)
		os.Exit(1)
	}

	if err := createSymbolicLinks(); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating symbolic links: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("✅ Installation completed successfully!")
}

// --- Helper function to run commands ---

func runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	fmt.Printf("▶️ Running: %s %v\n", name, args)
	return cmd.Run()
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

// --- Dependency installation ---

func installDependencies() error {
	fmt.Println("▶️ Installing dependencies...")
	switch runtime.GOOS {
	case "darwin":
		return installDependenciesMacOS()
	case "linux":
		return installDependenciesLinux()
	default:
		return fmt.Errorf("unsupported OS: %s", runtime.GOOS)
	}
}

func installDependenciesMacOS() error {
	fmt.Println("OS: macOS")
	if !commandExists("brew") {
		return fmt.Errorf("Homebrew is not installed. Please install it from https://brew.sh/")
	}

	packages := []string{"go", "neovim", "node"}
	fmt.Println("Installing packages with Homebrew:", packages)
	args := append([]string{"install"}, packages...)
	if err := runCommand("brew", args...); err != nil {
		return fmt.Errorf("failed to install packages with brew: %w", err)
	}

	fmt.Println("Installing uv...")
	if err := runCommand("sh", "-c", "curl -LsSf https://astral.sh/uv/install.sh | sh"); err != nil {
		return fmt.Errorf("failed to install uv: %w", err)
	}

	return nil
}

func installDependenciesLinux() error {
	fmt.Println("OS: Linux")
	if !commandExists("apt") {
		return fmt.Errorf("apt package manager not found. This script currently supports Debian-based systems.")
	}

	fmt.Println("Updating package list with apt...")
	if err := runCommand("sudo", "apt", "update"); err != nil {
		return fmt.Errorf("failed to update apt: %w", err)
	}

	// Note: package names might differ across distributions.
	packages := []string{"golang-go", "neovim", "nodejs", "npm"}
	fmt.Println("Installing packages with apt:", packages)
	args := append([]string{"install", "-y"}, packages...)
	if err := runCommand("sudo", "apt", args...); err != nil {
		return fmt.Errorf("failed to install packages with apt: %w", err)
	}

	fmt.Println("Installing uv...")
	if err := runCommand("sh", "-c", "curl -LsSf https://astral.sh/uv/install.sh | sh"); err != nil {
		return fmt.Errorf("failed to install uv: %w", err)
	}

	return nil
}

// --- Symbolic link creation ---

// linkTarget defines a source file/dir in the repo and its target link path.
type linkTarget struct {
	source string
	target string
}

func createSymbolicLinks() error {
	fmt.Println("▶️ Creating symbolic links...")

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("could not get home directory: %w", err)
	}

	// The installer binary might be run from the 'installer' subdir or the repo root.
	// We need to find the dotfiles root, which contains the '.git' directory.
	dotfilesDir, err := findDotfilesRoot()
	if err != nil {
		return err
	}

	targets := []linkTarget{
		{source: ".zshrc", target: ".zshrc"},
		{source: ".config", target: ".config"},
	}

	for _, t := range targets {
		sourcePath := filepath.Join(dotfilesDir, t.source)
		targetPath := filepath.Join(homeDir, t.target)

		fmt.Printf("Processing link for %s\n", t.source)

		// Check if the target already exists
		if _, err := os.Lstat(targetPath); err == nil {
			// It exists, create a backup
			backupPath := targetPath + ".bak." + time.Now().Format("20060102150405")
			fmt.Printf("  Target exists. Creating backup: %s\n", backupPath)
			if err := os.Rename(targetPath, backupPath); err != nil {
				return fmt.Errorf("failed to create backup for %s: %w", targetPath, err)
			}
		} else if !os.IsNotExist(err) {
			// An error other than "not exist" occurred
			return fmt.Errorf("failed to check target %s: %w", targetPath, err)
		}

		// Ensure the parent directory of the target exists
		targetDir := filepath.Dir(targetPath)
		if err := os.MkdirAll(targetDir, 0755); err != nil {
			return fmt.Errorf("failed to create parent directory %s: %w", targetDir, err)
		}

		// Create the symbolic link
		fmt.Printf("  Creating symlink: %s -> %s\n", sourcePath, targetPath)
		if err := os.Symlink(sourcePath, targetPath); err != nil {
			return fmt.Errorf("failed to create symlink for %s: %w", t.source, err)
		}
	}

	return nil
}

// findDotfilesRoot finds the root of the dotfiles repository by searching upwards for a .git directory.
func findDotfilesRoot() (string, error) {
	currentDir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		gitPath := filepath.Join(currentDir, ".git")
		if _, err := os.Stat(gitPath); err == nil {
			return currentDir, nil
		}

		parentDir := filepath.Dir(currentDir)
		if parentDir == currentDir {
			return "", fmt.Errorf("reached filesystem root without finding .git directory")
		}
		currentDir = parentDir
	}
}