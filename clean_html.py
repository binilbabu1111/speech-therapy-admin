import re

def clean_html():
    with open('orchids_raw.html', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Fix Typos and Email
    content = content.replace('JizzWorld', 'JisWorld')
    content = content.replace('hello@jizzworldtherapy.com', 'hello@jisworld.com')

    # 2. Remove Scripts
    # This regex is a bit aggressive, but safe if scripts are well-formed. 
    # Logic: Remove <script ...>...</script> (non-greedy)
    content = re.sub(r'<script\b[^>]*>.*?</script>', '', content, flags=re.DOTALL)
    
    # 3. Remove CSS links and Preloads to clean up
    content = re.sub(r'<link\b[^>]*rel="stylesheet"[^>]*>', '', content)
    content = re.sub(r'<link\b[^>]*rel="preload"[^>]*>', '', content)
    content = re.sub(r'<link\b[^>]*as="script"[^>]*>', '', content)

    # 4. Inject Local CSS
    # Find </head> and insert link before it
    local_css = '<link rel="stylesheet" href="style.css">'
    content = content.replace('</head>', f'{local_css}\n</head>')

    # 5. Fix Mobile Button ID
    # Look for button with aria-label="Toggle menu"
    if 'aria-label="Toggle menu"' in content:
        content = content.replace('aria-label="Toggle menu"', 'id="mobile-menu-btn" aria-label="Toggle menu"')
    
    # 6. Inject Mobile Menu
    # Insert before last closing div of nav or inside nav.
    # The nav ends with </nav>. We want to put it inside nav, at the end.
    mobile_menu_html = '''
    <!-- Mobile Menu (Hidden by default) -->
    <div id="mobile-menu" class="hidden lg:hidden bg-white border-t border-[#E2E8F0]">
        <div class="flex flex-col px-4 py-4 space-y-2">
            <a href="#home" class="px-3 py-2 text-base font-medium text-[#4A5568] hover:bg-[#F0F7F4] rounded-lg">Home</a>
            <a href="#about" class="px-3 py-2 text-base font-medium text-[#4A5568] hover:bg-[#F0F7F4] rounded-lg">About Us</a>
            <a href="#services" class="px-3 py-2 text-base font-medium text-[#4A5568] hover:bg-[#F0F7F4] rounded-lg">Services</a>
            <a href="#approach" class="px-3 py-2 text-base font-medium text-[#4A5568] hover:bg-[#F0F7F4] rounded-lg">Approach</a>
            <a href="#why-us" class="px-3 py-2 text-base font-medium text-[#4A5568] hover:bg-[#F0F7F4] rounded-lg">Why Choose Us</a>
            <a href="#contact" class="px-3 py-2 text-base font-medium text-[#4A5568] hover:bg-[#F0F7F4] rounded-lg">Contact</a>
        </div>
    </div>
    '''
    
    # Locate </nav> and insert before
    if '</nav>' in content:
        content = content.replace('</nav>', f'{mobile_menu_html}\n</nav>')
        
    # 7. Inject script.js
    local_js = '<script src="script.js"></script>'
    content = content.replace('</body>', f'{local_js}\n</body>')
    
    # 8. Remove data-orchids-id attributes (cleanup)
    content = re.sub(r'\sdata-orchids-[a-z]+="[^"]*"', '', content)
    content = re.sub(r'\sdata-map-index="[^"]*"', '', content)

    # Save to index.html
    with open('index.html', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    clean_html()
