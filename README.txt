ONeness Retailer Final UI v3
===========================

Customer pages remain separate:
- index.html                  Login / Account / Orders
- retailer-dashboard.html     Ecommerce home / catalogue
- product.html                Product detail
- cart.html                   Cart
- address.html                Delivery address
- payment.html                Checkout / payment
- earnings.html               Potential earnings analytics

Shared:
- retailer-ui-v3.css          Dedicated desktop + simplified mobile UI
- retailer-ui-v3.js           Branding, language, lazy images, dynamic splash
- retailer-splash-backend.sql Existing splash backend reference

WHAT CHANGED
------------
1. Desktop is now a dedicated ecommerce/website UI, not a stretched mobile layout.
2. Mobile was simplified: fewer helper lines, less visual clutter, clearer text hierarchy.
3. Home now loads the same retailer_earnings_dashboard data used by earnings.html.
   This fixes the mismatch where Earnings showed values but Home showed Tracking/blank.
4. Dashboard and Earnings cache the last successful payload per signed-in user in sessionStorage,
   so repeat visits paint immediately while fresh data loads.
5. Product images are progressively loaded:
   - first visible home images are prioritized
   - off-screen catalogue, cart, recommendation and thumbnail images use IntersectionObserver
   - decoding is asynchronous
6. Splash posters no longer open as an empty/blank overlay while the poster image is downloading.
   The first image is preloaded before the splash is displayed.
7. Home has a real Search button and Enter-to-search behavior.
8. No hard-coded earnings or prices were added.
