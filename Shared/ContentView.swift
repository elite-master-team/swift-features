import SwiftUI

struct Address: Identifiable, Decodable {
    let id = UUID()
    let endereco: String
    let cidade: String
    let estado: String
    let zip: String
    let servico: String
    let frequencia: String

    private enum CodingKeys: String, CodingKey {
        case endereco, cidade, estado, zip, servico, frequencia
    }
}

struct ResponseData: Decodable {
    let enderecos: [Address]
}

struct ContentView: View {
    @State private var addresses: [Address] = []
    @State private var groupedAddresses: [String: [Address]] = [:]
    

    var body: some View {
        NavigationView {
            List {
                ForEach(groupedAddresses.keys.sorted(), id: \.self) { city in
                    Section(header: Text(city)) {
                        ForEach(groupedAddresses[city]!) { address in
                            VStack(alignment: .leading) {
                                Text("Serviço: \(address.servico)")
                                Text("\(address.endereco)")
                                Text("\(address.estado) \(address.zip)")
                                
                                
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lista de Endereços")
            .onAppear {
                fetchAddresses { result in
                    switch result {
                    case .success(let fetchedAddresses):
                        print("----> sucesso")
                        self.addresses = fetchedAddresses
                        self.groupAddressesByCity()
                        print("==> " + fetchedAddresses.map { "\($0.endereco), \($0.cidade), \($0.estado), \($0.zip)" }.joined(separator: "\n"))
                    case .failure(let error):
                        print("-----> Failed to fetch addresses: \(error.localizedDescription)")
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

func fetchAddresses(completion: @escaping (Result<[Address], Error>) -> Void) {
    guard let url = URL(string: "https://pwms.com.br/backends/invoices-v3/public/buscarRotaGeraisEdicaoV2?data=2024-07-7") else {
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
            let responseData = try JSONDecoder().decode(ResponseData.self, from: data)
            print("Dados JSON recebidos e decodificados com sucesso: \(responseData.enderecos)")
            completion(.success(responseData.enderecos))
        } catch {
            print("Erro ao decodificar dados JSON: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    task.resume()
}
