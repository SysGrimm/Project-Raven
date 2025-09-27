# Pi-CI Testing Integration

## Overview

Pi-CI provides Docker-based Raspberry Pi emulation for testing Project Raven configurations locally without requiring physical hardware.

## What is Pi-CI?

Pi-CI is a containerized Raspberry Pi environment that enables:
- **Local Testing**: Test configurations before building releases
- **Raspberry Pi OS Support**: Validate our Pi OS implementation  
- **Virtual Environment**: Safe testing without hardware requirements
- **Automated Testing**: Integration with CI/CD pipelines

## Supported Configurations

### Hardware Emulation
- **Raspberry Pi 3, 4, and 5** [SUCCESS]
- **64-bit ARM (ARMv8)** architecture
- **Base OS**: Raspberry Pi OS Bookworm (2024-07-04)
- **Kernel**: Linux 6.6-y
- **Networking**: Full network stack with SSH access

### Project Raven Integration
- **Kodi Configuration**: Test media center setup
- **CEC Emulation**: Validate remote control integration
- **Tailscale Testing**: VPN functionality validation
- **Performance Testing**: System optimization verification

## Usage Guide

### Quick Start
```bash
# Pull the Pi-CI image
docker pull ghcr.io/toolboc/pi-ci:rpi4

# Run Project Raven test
cd Project-Raven
./raspios/scripts/pi-ci-test.sh
```

### Manual Testing
```bash
# Start Pi-CI container with Project Raven mounted
docker run -it --rm \
  -v "$(pwd)":/workspace \
  -p 2222:22 \
  ghcr.io/toolboc/pi-ci:rpi4

# Inside container, run tests
cd /workspace
./raspios/scripts/configure-kodi.sh --test-mode
./raspios/scripts/optimize-video.sh --validate
```

### SSH Access
```bash
# Connect to running Pi-CI container
ssh pi@localhost -p 2222
# Default password: raspberry
```

## Testing Scenarios

### 1. Kodi Configuration Testing
```bash
# Test Kodi setup without X11 requirements
./configure-kodi.sh --headless-test
```
- Validates configuration file generation
- Checks service configuration
- Verifies permissions and ownership

### 2. Video Optimization Testing
```bash
# Test LibreELEC optimizations
./optimize-video.sh --dry-run
```
- Validates Pi model detection
- Checks memory allocation logic
- Tests configuration file generation

### 3. System Integration Testing
```bash
# Full system test
./pi-ci-test.sh --full-suite
```
- Tests complete build process
- Validates all configurations
- Checks service dependencies

### 4. Network Configuration Testing
```bash
# Test Tailscale integration
./pi-ci-test.sh --network-test
```
- Validates VPN configuration
- Tests network connectivity
- Checks firewall rules

## Automated Testing Pipeline

### GitHub Actions Integration
```yaml
name: Pi-CI Testing
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Pi-CI Tests
        run: |
          docker pull ghcr.io/toolboc/pi-ci:rpi4
          ./raspios/scripts/pi-ci-test.sh --ci-mode
```

### Local CI Testing
```bash
# Run full test suite locally
./scripts/pi-ci-test.sh --complete

# Test specific components
./scripts/pi-ci-test.sh --component kodi
./scripts/pi-ci-test.sh --component video-opt
./scripts/pi-ci-test.sh --component tailscale
```

## Test Coverage

### Configuration Validation
- [SUCCESS] **Boot Configuration**: /boot/firmware/config.txt validation
- [SUCCESS] **Systemd Services**: Service file generation and validation
- [SUCCESS] **User Configuration**: Kodi user setup and permissions
- [SUCCESS] **Network Configuration**: Tailscale and networking setup

### Performance Validation  
- [SUCCESS] **Memory Allocation**: GPU memory split validation
- [SUCCESS] **Hardware Detection**: Pi model identification
- [SUCCESS] **Optimization Application**: LibreELEC optimization verification
- [SUCCESS] **Service Integration**: Systemd service functionality

### Integration Validation
- [SUCCESS] **Build Process**: Complete image build testing
- [SUCCESS] **First Boot**: First-boot script execution
- [SUCCESS] **Error Handling**: Error detection and recovery
- [SUCCESS] **Status Monitoring**: Performance monitoring tools

## Limitations and Workarounds

### Hardware Limitations
- **GPU Emulation**: Limited graphics acceleration
- **CEC Hardware**: Physical CEC testing not possible
- **Performance**: Emulated performance differs from real hardware

### Workarounds
- **Configuration Testing**: Focus on config file validation
- **Service Testing**: Test service setup without hardware dependencies  
- **Logic Validation**: Validate decision logic and error handling
- **Integration Testing**: Test component integration patterns

## Debugging and Troubleshooting

### Common Issues

#### Container Access Issues
```bash
# Fix permission issues
docker run --privileged -v "$(pwd)":/workspace ghcr.io/toolboc/pi-ci:rpi4
```

#### Network Connectivity
```bash
# Check network configuration
docker run --network host ghcr.io/toolboc/pi-ci:rpi4
```

#### SSH Connection Problems
```bash
# Check SSH service status
docker exec -it container_id systemctl status ssh
```

### Debug Mode
```bash
# Run tests with debug output
./pi-ci-test.sh --debug --verbose
```

### Log Analysis
```bash
# Check test logs
tail -f /var/log/pi-ci-test.log

# Check system logs  
journalctl -f
```

## Performance Considerations

### Resource Usage
- **CPU**: 2-4 cores recommended
- **Memory**: 4GB minimum, 8GB recommended
- **Storage**: 20GB for full testing suite
- **Network**: Broadband connection for image downloads

### Optimization Tips
- **Image Caching**: Cache Pi-CI images locally
- **Parallel Testing**: Run tests in parallel where possible
- **Incremental Testing**: Test only changed components
- **Resource Limits**: Use Docker resource constraints

## Integration Benefits

### Development Workflow
1. **Local Development**: Test changes immediately
2. **Continuous Integration**: Automated testing on commits
3. **Pull Request Validation**: Test contributions before merge
4. **Release Validation**: Comprehensive testing before release

### Quality Assurance
- **Configuration Validation**: Ensure configs are valid
- **Integration Testing**: Test component interactions
- **Regression Testing**: Prevent feature regression
- **Performance Testing**: Monitor optimization effectiveness

## Future Enhancements

### Planned Improvements
1. **GPU Acceleration**: Better graphics emulation
2. **Hardware Simulation**: Mock CEC and other hardware interfaces
3. **Performance Profiling**: Detailed performance analysis
4. **Multi-Architecture**: Support for different Pi models

### Community Integration
1. **Shared Test Suite**: Community-contributed tests
2. **Test Result Sharing**: Public test result dashboard  
3. **Issue Integration**: Link test failures to GitHub issues
4. **Documentation**: Community testing guides
