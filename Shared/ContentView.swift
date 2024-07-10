import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}


struct Address: Identifiable, Decodable {
    let id = UUID()
    let endereco: String
    let cidade: String
    let estado: String
    let zip: String?
    let servico: String
    let frequencia: String

    private enum CodingKeys: String, CodingKey {
        case endereco, cidade, estado, zip, servico, frequencia
    }
}

struct ResponseData: Decodable {
    let enderecos: [Address]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let enderecosList = try? container.decode([Address].self, forKey: .enderecos) {
            self.enderecos = enderecosList
        } else if let enderecosDict = try? container.decode([String: Address].self, forKey: .enderecos) {
            self.enderecos = Array(enderecosDict.values)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .enderecos, in: container, debugDescription: "Formato de dados inesperado.")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case enderecos
    }
}

struct ContentView: View {
    @State private var addresses: [Address] = []
    @State private var groupedAddresses: [String: [Address]] = [:]
    @State private var showActionSheet = false
    @State private var selectedAddress: Address?
    @State private var selectedDate = Date()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select a date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .onChange(of: selectedDate, perform: { date in
                        fetchAddresses(for: date) { result in
                            switch result {
                            case .success(let fetchedAddresses):
                                self.addresses = fetchedAddresses
                                self.groupAddressesByCity()
                            case .failure(let error):
                                print("Failed to fetch addresses: \(error.localizedDescription)")
                            }
                        }
                    })
                    .padding()

                List {
                    ForEach(groupedAddresses.keys.sorted(), id: \.self) { city in
                        Section(header: Text(city)) {
                            ForEach(groupedAddresses[city]!) { address in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .foregroundColor(.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedAddress = address
                                            showActionSheet = true
                                        }
                                    VStack(alignment: .leading) {
                                        Text(address.endereco)
                                        Spacer()
                                    }
                                    .padding(.top, 10)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lista de Endereços")
            .onAppear {
                fetchAddresses(for: selectedDate) { result in
                    switch result {
                    case .success(let fetchedAddresses):
                        self.addresses = fetchedAddresses
                        self.groupAddressesByCity()
                    case .failure(let error):
                        print("Failed to fetch addresses: \(error.localizedDescription)")
                    }
                }
            }
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(title: Text("Escolha uma opção"), buttons: [
                    .default(Text("Take a picture")) {
                        showImagePicker = true
                    },
                    .default(Text("Delete")) {
                        print("Opção 2 selecionada para \(selectedAddress?.endereco ?? "")")
                    },
                    .default(Text("Maps")) {
                        print("Opção 3 selecionada para \(selectedAddress?.endereco ?? "")")
                    },
                    .cancel()
                ])
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
                    .onDisappear {
                        if let image = selectedImage {
                            if let url = URL(string: "https://your-api-endpoint.com/upload") {
                                uploadImage(image, to: url) { result in
                                    switch result {
                                    case .success:
                                        print("Image uploaded successfully")
                                    case .failure(let error):
                                        print("Failed to upload image: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }

    private func groupAddressesByCity() {
        groupedAddresses = Dictionary(grouping: addresses, by: { $0.cidade })
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

func fetchAddresses(for date: Date, completion: @escaping (Result<[Address], Error>) -> Void) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: date)
    
    guard let url = URL(string: "https://pwms.com.br/backends/invoices-v3/public/buscarRotaGeraisEdicaoV2?data=\(dateString)") else {
        print("URL inválida.")
        return
    }

    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        if let error = error {
            print("Erro ao realizar requisição: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Erro de resposta do servidor.")
            let responseError = NSError(domain: "", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Erro de resposta do servidor."])
            completion(.failure(responseError))
            return
        }

        guard let mimeType = httpResponse.mimeType, mimeType == "application/json",
              let data = data else {
            print("Formato de dados inesperado ou vazio.")
            let formatError = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Formato de dados inesperado ou vazio."])
            completion(.failure(formatError))
            return
        }

        do {
            print("dateString: \(dateString)")
            print("URL: \(url)")
            
            let jsonString = String(data: data, encoding: .utf8) ?? "Dados inválidos"
            //print("Dados JSON recebidos: \(jsonString)")
            
            let responseData = try JSONDecoder().decode(ResponseData.self, from: data)
            //print("Dados JSON decodificados com sucesso: \(responseData.enderecos)")
            completion(.success(responseData.enderecos))
        } catch {
            print("Erro ao decodificar dados JSON: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    task.resume()
}

func uploadImage(_ image: UIImage, to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        completion(.failure(NSError(domain: "ImageConversionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var body = Data()
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(imageData)
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = body
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let responseError = NSError(domain: "", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
            completion(.failure(responseError))
            return
        }

        completion(.success(()))
    }.resume()
}
