# Project Raven AI Assistant Configuration

## Project Overview
You are working on **Project Raven**, a custom Raspberry Pi media center distribution that:
- Implements LibreELEC-style video optimizations for maximum performance
- Features mandatory Project Raven boot splash branding
- Focuses on ARM64 Raspberry Pi 4/5 optimization
- Provides automated build system for custom Raspberry Pi OS images
- Includes comprehensive video acceleration and thermal management

## Technical Context
- **Base OS**: Raspberry Pi OS Bookworm (ARM64)
- **Target Hardware**: Raspberry Pi 4/5 with focus on video playback
- **Key Technologies**: FFmpeg, V4L2, GPU memory management, CMA optimization
- **Build System**: Bash-based image customization with first-boot automation
- **Testing**: Pi-CI integration for hardware-less development

## Working Principles
1. **Performance First**: All decisions prioritize video playback performance
2. **Mandatory Branding**: Boot splash with Project Raven logo is non-optional
3. **Thermal Awareness**: Consider heat generation in all optimizations
4. **Build Reliability**: Image builds must be reproducible and error-handled
5. **Documentation**: Maintain wiki documentation for all technical decisions

## Code Standards
- Use absolute paths in all scripts
- Include comprehensive error handling with proper exit codes
- Test syntax with `bash -n` after script modifications
- Validate changes against LibreELEC compatibility where applicable
- Maintain first-boot automation reliability

## Communication Style
- Be technical and precise, especially for video optimization details
- Explain the "why" behind performance decisions
- Reference LibreELEC implementations when relevant  
- Show terminal commands before executing them
- Do not use emoji's or emoticons for any reason.

## Workflow Guidelines
1. Check existing implementations before making changes
2. Validate all script syntax after modifications
3. Update wiki documentation for user-facing features
4. Consider performance impact of all changes
5. Test critical paths (build, first-boot, video optimization)
6. Maintain backwards compatibility unless explicitly requested otherwise

## Project Structure Awareness
- `raspios/scripts/`: Core build and optimization scripts
- `raspios/configurations/`: System configuration files and assets
- `wiki/`: Comprehensive project documentation
- `archive/`: Historical files and cleanup artifacts

## Error Handling Philosophy
- Fail fast on critical errors (missing logo, broken builds)
- Provide clear error messages with actionable solutions
- Log all operations for debugging and audit trails
- Never silently ignore configuration failures
