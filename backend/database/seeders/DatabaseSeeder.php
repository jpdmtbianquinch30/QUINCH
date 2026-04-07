<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ─── Categories ─────────────────────────────────────────────────
        $categories = [
            ['name' => 'Téléphones & Tech', 'slug' => 'telephones-tech', 'icon' => 'phone_iphone', 'sort_order' => 1],
            ['name' => 'Mode & Accessoires', 'slug' => 'mode-accessoires', 'icon' => 'style', 'sort_order' => 2],
            ['name' => 'Maison & Déco', 'slug' => 'maison-deco', 'icon' => 'home', 'sort_order' => 3],
            ['name' => 'Véhicules', 'slug' => 'vehicules', 'icon' => 'directions_car', 'sort_order' => 4],
            ['name' => 'Sports & Loisirs', 'slug' => 'sports-loisirs', 'icon' => 'sports_basketball', 'sort_order' => 5],
            ['name' => 'Beauté & Santé', 'slug' => 'beaute-sante', 'icon' => 'spa', 'sort_order' => 6],
            ['name' => 'Électroménager', 'slug' => 'electromenager', 'icon' => 'kitchen', 'sort_order' => 7],
            ['name' => 'Services', 'slug' => 'services', 'icon' => 'handyman', 'sort_order' => 8],
        ];

        $categoryIds = [];
        foreach ($categories as $cat) {
            $cat['id'] = (string) Str::uuid();
            Category::create($cat);
            $categoryIds[] = $cat['id'];
        }

        // ─── Admin User ─────────────────────────────────────────────────
        $admin = User::create([
            'phone_number' => '+221770000001',
            'email' => 'admin@quinch.sn',
            'username' => 'admin_quinch',
            'full_name' => 'Admin QUINCH',
            'password' => 'password',
            'role' => 'super_admin',
            'trust_score' => 1.0,
            'kyc_status' => 'verified',
            'phone_verified' => true,
            'onboarding_completed' => true,
            'is_seller' => true,
            'is_buyer' => true,
            'city' => 'Dakar',
            'region' => 'Dakar',
        ]);

        // ─── Senegal Test Users ─────────────────────────────────────────
        $senegalCities = [
            ['city' => 'Dakar', 'region' => 'Dakar'],
            ['city' => 'Saint-Louis', 'region' => 'Saint-Louis'],
            ['city' => 'Thiès', 'region' => 'Thiès'],
            ['city' => 'Kaolack', 'region' => 'Kaolack'],
            ['city' => 'Ziguinchor', 'region' => 'Ziguinchor'],
            ['city' => 'Touba', 'region' => 'Diourbel'],
            ['city' => 'Mbour', 'region' => 'Thiès'],
            ['city' => 'Rufisque', 'region' => 'Dakar'],
        ];

        $senegalNames = [
            'Abdoulaye Diallo', 'Fatou Ndiaye', 'Moussa Sarr', 'Aminata Sow',
            'Ibrahima Fall', 'Mariama Bâ', 'Ousmane Seck', 'Aïssatou Diop',
            'Cheikh Mbaye', 'Coumba Gueye', 'Pape Ndoye', 'Khady Thiam',
            'Mamadou Kane', 'Sokhna Dieng', 'Alioune Sy', 'Rama Touré',
            'Babacar Niang', 'Dieynaba Camara', 'Modou Lo', 'Awa Cissé',
        ];

        $users = [];
        foreach ($senegalNames as $i => $name) {
            $location = $senegalCities[$i % count($senegalCities)];
            $users[] = User::create([
                'phone_number' => '+22177' . str_pad($i + 10, 7, '0', STR_PAD_LEFT),
                'username' => Str::slug(explode(' ', $name)[0]) . ($i + 1),
                'full_name' => $name,
                'password' => 'password',
                'trust_score' => round(0.3 + (mt_rand(0, 70) / 100), 2),
                'kyc_status' => $i < 10 ? 'verified' : 'pending',
                'phone_verified' => $i < 15,
                'onboarding_completed' => true,
                'role' => 'user',
                'is_seller' => true,
                'is_buyer' => true,
                'city' => $location['city'],
                'region' => $location['region'],
            ]);
        }

        // ─── Sample Products ────────────────────────────────────────────
        $sampleProducts = [
            ['title' => 'iPhone 15 Pro Max 256Go', 'price' => 850000, 'cat' => 0, 'condition' => 'new'],
            ['title' => 'Samsung Galaxy S24 Ultra', 'price' => 750000, 'cat' => 0, 'condition' => 'new'],
            ['title' => 'MacBook Air M3 2024', 'price' => 950000, 'cat' => 0, 'condition' => 'like_new'],
            ['title' => 'Tecno Spark 20 Pro', 'price' => 125000, 'cat' => 0, 'condition' => 'new'],
            ['title' => 'AirPods Pro 2ème Génération', 'price' => 85000, 'cat' => 0, 'condition' => 'new'],
            ['title' => 'Boubou Bazin riche homme', 'price' => 45000, 'cat' => 1, 'condition' => 'new'],
            ['title' => 'Robe wax africaine taille M', 'price' => 25000, 'cat' => 1, 'condition' => 'new'],
            ['title' => 'Sneakers Nike Air Max 90', 'price' => 65000, 'cat' => 1, 'condition' => 'like_new'],
            ['title' => 'Montre Casio G-Shock', 'price' => 35000, 'cat' => 1, 'condition' => 'new'],
            ['title' => 'Sac à main en cuir véritable', 'price' => 55000, 'cat' => 1, 'condition' => 'new'],
            ['title' => 'Canapé 3 places moderne', 'price' => 180000, 'cat' => 2, 'condition' => 'new'],
            ['title' => 'Table à manger 6 places', 'price' => 120000, 'cat' => 2, 'condition' => 'good'],
            ['title' => 'Tapis berbère fait main', 'price' => 75000, 'cat' => 2, 'condition' => 'new'],
            ['title' => 'Toyota Corolla 2020 Essence', 'price' => 8500000, 'cat' => 3, 'condition' => 'good'],
            ['title' => 'Moto Jakarta 125cc', 'price' => 450000, 'cat' => 3, 'condition' => 'fair'],
            ['title' => 'Ballon de Football Officiel', 'price' => 15000, 'cat' => 4, 'condition' => 'new'],
            ['title' => 'Vélo VTT Adulte 26 pouces', 'price' => 95000, 'cat' => 4, 'condition' => 'like_new'],
            ['title' => 'Crème éclaircissante naturelle Bio', 'price' => 8000, 'cat' => 5, 'condition' => 'new'],
            ['title' => 'Parfum Arabian Oud 100ml', 'price' => 35000, 'cat' => 5, 'condition' => 'new'],
            ['title' => 'Climatiseur Samsung 12000 BTU', 'price' => 250000, 'cat' => 6, 'condition' => 'new'],
            ['title' => 'Réfrigérateur LG 300L', 'price' => 320000, 'cat' => 6, 'condition' => 'new'],
            ['title' => 'Machine à laver automatique 7kg', 'price' => 195000, 'cat' => 6, 'condition' => 'like_new'],
            ['title' => 'Cours de Wolof en ligne', 'price' => 15000, 'cat' => 7, 'condition' => 'new'],
            ['title' => 'Service traiteur 50 personnes', 'price' => 250000, 'cat' => 7, 'condition' => 'new'],
            ['title' => 'Xiaomi Redmi Note 13', 'price' => 110000, 'cat' => 0, 'condition' => 'new'],
            ['title' => 'PlayStation 5 avec 2 manettes', 'price' => 425000, 'cat' => 4, 'condition' => 'like_new'],
            ['title' => 'Ensemble Thioup Sénégalais', 'price' => 30000, 'cat' => 1, 'condition' => 'new'],
            ['title' => 'Groupe électrogène 5KVA', 'price' => 350000, 'cat' => 6, 'condition' => 'new'],
            ['title' => 'TV Samsung 55 pouces 4K', 'price' => 380000, 'cat' => 0, 'condition' => 'new'],
            ['title' => 'Panneau solaire 300W complet', 'price' => 175000, 'cat' => 6, 'condition' => 'new'],
        ];

        $sellers = collect($users)->values();

        foreach ($sampleProducts as $i => $item) {
            $seller = $sellers[$i % $sellers->count()];

            // Create a video placeholder for the product
            $video = ProductVideo::create([
                'user_id' => $seller->id,
                'video_path' => 'videos/demo/sample-' . ($i + 1) . '.mp4',
                'thumbnail_path' => 'videos/demo/thumb-' . ($i + 1) . '.jpg',
                'duration_seconds' => rand(8, 30),
                'format' => 'mp4',
                'size_bytes' => rand(1000000, 15000000),
                'processing_status' => 'completed',
                'moderation_status' => 'approved',
                'view_count' => rand(10, 5000),
                'engagement_score' => round(mt_rand(10, 95) / 10, 2),
            ]);

            Product::create([
                'user_id' => $seller->id,
                'title' => $item['title'],
                'description' => 'Produit de qualité disponible sur QUINCH. ' . $item['title'] . '. Livraison possible dans toute la région. Contactez-nous pour plus de détails.',
                'category_id' => $categoryIds[$item['cat']],
                'price' => $item['price'],
                'currency' => 'XOF',
                'condition' => $item['condition'],
                'is_negotiable' => rand(0, 1),
                'status' => 'active',
                'video_id' => $video->id,
                'view_count' => rand(5, 2000),
                'like_count' => rand(0, 500),
                'share_count' => rand(0, 100),
            ]);
        }

        // ─── Sample Transactions ────────────────────────────────────────
        $products = Product::all();
        $paymentMethods = ['orange_money', 'wave', 'free_money', 'cash_delivery'];

        for ($i = 0; $i < 15; $i++) {
            $product = $products->random();
            $buyer = collect($users)->filter(fn($u) => $u->id !== $product->user_id)->random();

            Transaction::create([
                'buyer_id' => $buyer->id,
                'seller_id' => $product->user_id,
                'product_id' => $product->id,
                'amount' => $product->price,
                'currency' => 'XOF',
                'payment_method' => $paymentMethods[array_rand($paymentMethods)],
                'payment_status' => $i < 10 ? 'completed' : 'pending',
                'security_check' => $i < 10 ? 'passed' : 'pending',
                'delivery_type' => ['pickup', 'delivery', 'meetup'][rand(0, 2)],
                'transaction_fee' => round($product->price * 0.025, 2),
                'completed_at' => $i < 10 ? now()->subDays(rand(1, 30)) : null,
            ]);
        }

        $this->command->info('✅ QUINCH database seeded with Senegal data!');
        $this->command->info("   Admin: +221770000001 / password");
        $this->command->info("   Users: 20 test users created");
        $this->command->info("   Products: " . Product::count() . " products created");
        $this->command->info("   Transactions: " . Transaction::count() . " transactions created");
    }
}
