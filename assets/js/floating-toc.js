document.addEventListener('DOMContentLoaded', function() {
    const toc = document.querySelector('.floating-toc');
    const tocHeader = document.querySelector('.toc-header');
    const tocLinks = document.querySelectorAll('.toc-nav a');
    const sections = [];
    
    if (!toc) return;
    
    // Initialize sections array with their elements and offsets
    tocLinks.forEach(link => {
        const targetId = link.getAttribute('href').substring(1);
        const targetElement = document.getElementById(targetId);
        if (targetElement) {
            sections.push({
                id: targetId,
                element: targetElement,
                link: link,
                offset: 0 // Will be updated dynamically
            });
        }
    });
    
    // Toggle TOC collapse/expand
    tocHeader.addEventListener('click', function() {
        toc.classList.toggle('collapsed');

        // Close nav menu when expanding TOC
        if (!toc.classList.contains('collapsed')) {
          const navMenu = document.querySelector('.nav-menu');
          const menuToggle = document.querySelector('.menu-toggle');
          if (navMenu) {
            navMenu.classList.remove('active');
            menuToggle.classList.remove('active');
            menuToggle.setAttribute('aria-expanded', 'false');
          }
        }

        // Save state to localStorage
        const isCollapsed = toc.classList.contains('collapsed');
        localStorage.setItem('tocCollapsed', isCollapsed);
    });
    
    // Restore TOC state from localStorage or set default based on screen width
    const savedState = localStorage.getItem('tocCollapsed');
    if (savedState !== null) {
        // Use saved state if it exists
        if (savedState === 'true') {
            toc.classList.add('collapsed');
        }
    } else {
        // Default to collapsed if screen width is less than 1660px
        if (window.innerWidth < 1660) {
            toc.classList.add('collapsed');
        }
    }
    
    // Smooth scrolling for TOC links
    tocLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);
            
            if (targetElement) {
                const headerOffset = 80; // Account for any fixed headers
                const elementPosition = targetElement.getBoundingClientRect().top;
                const offsetPosition = elementPosition + window.pageYOffset - headerOffset;
                
                window.scrollTo({
                    top: offsetPosition,
                    behavior: 'smooth'
                });
                
                // Update active state immediately
                updateActiveLink(targetId);
            }
        });
    });
    
    // Function to update section offsets (for responsive design)
    function updateSectionOffsets() {
        sections.forEach(section => {
            section.offset = section.element.getBoundingClientRect().top + window.pageYOffset;
        });
    }
    
    // Function to update active link based on current scroll position
    function updateActiveLink(forcedId = null) {
        if (forcedId) {
            // Force a specific link to be active
            tocLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === `#${forcedId}`) {
                    link.classList.add('active');
                }
            });
            return;
        }
        
        const scrollPosition = window.pageYOffset + 100; // Add offset for better UX
        let activeSection = null;
        
        // Find the current section based on scroll position
        for (let i = sections.length - 1; i >= 0; i--) {
            const section = sections[i];
            const sectionTop = section.element.getBoundingClientRect().top + window.pageYOffset;
            
            if (scrollPosition >= sectionTop) {
                activeSection = section;
                break;
            }
        }
        
        // Update active state
        tocLinks.forEach(link => link.classList.remove('active'));
        if (activeSection) {
            activeSection.link.classList.add('active');
        }
    }
    
    // Throttled scroll handler for performance
    let scrollTimeout;
    function handleScroll() {
        if (scrollTimeout) {
            clearTimeout(scrollTimeout);
        }
        scrollTimeout = setTimeout(() => {
            updateActiveLink();
        }, 16); // ~60fps
    }
    
    // Throttled resize handler
    let resizeTimeout;
    function handleResize() {
        if (resizeTimeout) {
            clearTimeout(resizeTimeout);
        }
        resizeTimeout = setTimeout(() => {
            updateSectionOffsets();
        }, 250);
    }
    
    // Add event listeners
    window.addEventListener('scroll', handleScroll, { passive: true });
    window.addEventListener('resize', handleResize, { passive: true });
    
    // Initial setup
    updateSectionOffsets();
    updateActiveLink();
    
    // Intersection Observer for more accurate section detection (modern browsers)
    if ('IntersectionObserver' in window) {
        const observerOptions = {
            root: null,
            rootMargin: '-20% 0px -60% 0px',
            threshold: 0
        };
        
        const observer = new IntersectionObserver((entries) => {
            let activeEntry = null;
            
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    activeEntry = entry;
                }
            });
            
            if (activeEntry) {
                const activeId = activeEntry.target.id;
                tocLinks.forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${activeId}`) {
                        link.classList.add('active');
                    }
                });
            }
        }, observerOptions);
        
        // Observe all sections
        sections.forEach(section => {
            if (section.element) {
                observer.observe(section.element);
            }
        });
        
        // Remove the scroll-based active link detection if Intersection Observer is supported
        window.removeEventListener('scroll', handleScroll);
    }
    
    // Hide TOC on very small screens when scrolling (optional UX enhancement)
    let lastScrollTop = 0;
    const hideThreshold = 100;
    
    if (window.innerWidth <= 480) {
        window.addEventListener('scroll', function() {
            const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
            
            // Only hide if TOC is not actively being used (collapsed)
            if (toc.classList.contains('collapsed') && Math.abs(scrollTop - lastScrollTop) > hideThreshold) {
                if (scrollTop > lastScrollTop && scrollTop > 200) {
                    // Scrolling down - hide TOC
                    toc.style.transform = 'translateY(150%)';
                } else {
                    // Scrolling up - show TOC
                    toc.style.transform = 'translateY(0)';
                }
                lastScrollTop = scrollTop;
            } else if (!toc.classList.contains('collapsed')) {
                // If TOC is expanded, always show it
                toc.style.transform = 'translateY(0)';
            }
        }, { passive: true });
    }
});