incus network set incusbr0 dns.domain=test
resolvectl dns incusbr0 $(ip -f inet addr show incusbr0 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
resolvectl domain incusbr0 '~test'
