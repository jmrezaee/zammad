# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Ruby 3.2+ introduced Regexp.timeout (default: nil = no timeout). Some gems
# or hosting environments may set it to a positive value. During Docker builds
# (ZAMMAD_SAFE_MODE=1) the arm64 QEMU emulator is slow enough that the terser
# gem's internal regex exceeds any non-nil timeout. Explicitly reset to nil.
Regexp.timeout = nil if ENV['ZAMMAD_SAFE_MODE'].present?
