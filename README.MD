## Proof-of-concept code that checks if there is any AUR package needs rebuild

## This isn't through tested

This works by check every linux executable provided by AUR packages (technically all foreign packages), if the executable is dynamically linking other library file, and that other library file doesn't exist, a package is deemed broken.