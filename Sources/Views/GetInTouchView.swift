import SwiftUI

struct GetInTouchView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Links requested by user
    private let address = "Shop 17, 179 Station Road, Burpengary QLD 4505\nInside Burpengary Plaza"
    private let phone = "+61430430484"
    private let phoneDisplay = "+61 430 430 484"
    private let mapsUrl = "https://maps.google.com/?q=Burpengary+Fruit+Market,+179+Station+Rd,+Burpengary+QLD+4505"
    private let whatsAppUrl = "https://wa.me/61430430484"
    private let facebookUrl = "https://www.facebook.com/BurpengaryFruitMarket"
    private let messengerUrl = "https://m.me/BurpengaryFruitMarket"

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF1/255.0)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.primaryGreen.opacity(0.25))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "basket.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Burpengary Fruit Market")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Your FRESH Shop & Local Loyalty")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(red: 0xD5/255.0, green: 0xE8/255.0, blue: 0xD4/255.0))
                                }
                            }
                            
                            Text("We are always here to help you with fresh produce queries, loyalty points, or special orders. Drop by our store or connect with us below!")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.88))
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.darkGreen)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                        
                        // 1. Store Address Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0xE8/255.0, green: 0xF5/255.0, blue: 0xE9/255.0))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.primaryGreen)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("📍 STORE ADDRESS")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppColors.primaryGreen)
                                    Text("Shop 17, 179 Station Road\nBurpengary QLD 4505")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(AppColors.darkGreen)
                                    Text("Inside Burpengary Plaza")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Link(destination: URL(string: mapsUrl)!) {
                                HStack {
                                    Image(systemName: "map.fill")
                                    Text("Open in Google Maps")
                                        .fontWeight(.bold)
                                }
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.primaryGreen)
                                .cornerRadius(12)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        
                        // 2. Direct Phone Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0xE8/255.0, green: 0xF5/255.0, blue: 0xE9/255.0))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.primaryGreen)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("📞 DIRECT PHONE")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppColors.primaryGreen)
                                    Text(phoneDisplay)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppColors.darkGreen)
                                    Text("Call our team for orders or general questions")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Link(destination: URL(string: "tel:\(phone)")!) {
                                HStack {
                                    Image(systemName: "phone.arrow.up.right.fill")
                                    Text("Call \(phoneDisplay)")
                                        .fontWeight(.bold)
                                }
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.darkGreen)
                                .cornerRadius(12)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        
                        // 3. WhatsApp Support Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0xE8/255.0, green: 0xF5/255.0, blue: 0xE9/255.0))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0x25/255.0, green: 0xD3/255.0, blue: 0x66/255.0))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("💬 WHATSAPP SUPPORT")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(red: 0x25/255.0, green: 0xD3/255.0, blue: 0x66/255.0))
                                    Text(phoneDisplay)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppColors.darkGreen)
                                    Text("Instant chat for loyalty inquiries and produce orders")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Link(destination: URL(string: whatsAppUrl)!) {
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                    Text("Chat on WhatsApp")
                                        .fontWeight(.bold)
                                }
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(red: 0x25/255.0, green: 0xD3/255.0, blue: 0x66/255.0))
                                .cornerRadius(12)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        
                        // 4. Facebook & Messenger Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0xE3/255.0, green: 0xF2/255.0, blue: 0xFD/255.0))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "globe")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0x18/255.0, green: 0x77/255.0, blue: 0xF2/255.0))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("SOCIAL & COMMUNITY")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(red: 0x18/255.0, green: 0x77/255.0, blue: 0xF2/255.0))
                                    Text("@BurpengaryFruitMarket")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppColors.darkGreen)
                                    Text("Daily fresh specials, deals and community updates")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Link(destination: URL(string: facebookUrl)!) {
                                    Text("Facebook Page")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(Color(red: 0x18/255.0, green: 0x77/255.0, blue: 0xF2/255.0))
                                        .cornerRadius(12)
                                }
                                
                                Link(destination: URL(string: messengerUrl)!) {
                                    Text("Messenger")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(red: 0x00/255.0, green: 0x84/255.0, blue: 0xFF/255.0))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(red: 0x00/255.0, green: 0x84/255.0, blue: 0xFF/255.0), lineWidth: 1.5)
                                        )
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        
                        // 5. Trading Hours Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(AppColors.primaryGreen)
                                Text("Store Trading Hours")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppColors.darkGreen)
                            }
                            
                            Text("• Monday – Saturday: 7:00 AM – 6:00 PM\n• Sunday: 8:00 AM – 5:00 PM")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                            
                            Text("Burpengary Plaza • Shop 17, 179 Station Rd")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Get in Touch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primaryGreen)
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
}
