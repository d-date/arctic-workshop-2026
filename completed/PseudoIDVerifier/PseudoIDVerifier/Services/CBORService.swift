import Foundation
import SwiftCBOR

// MARK: - CBOR Encoding/Decoding Service

/// Service for encoding and decoding CBOR data according to ISO 18013-5
nonisolated class CBORService: @unchecked Sendable {
    static let shared = CBORService()

    private init() {}

    // MARK: - CBOR Encoding

    /// Encode an mdoc to CBOR format
    func encode(mdoc: MDoc) -> Data {
        var map: [CBOR: CBOR] = [:]

        // docType
        map[.utf8String("docType")] = .utf8String(mdoc.docType)

        // issuerSigned
        var issuerSignedMap: [CBOR: CBOR] = [:]

        // nameSpaces
        var nameSpacesMap: [CBOR: CBOR] = [:]
        for (namespace, items) in mdoc.issuerSigned.nameSpaces {
            var itemsArray: [CBOR] = []
            for item in items {
                // Each item is encoded as a tagged bstr (tag 24)
                let itemCBOR = encodeIssuerSignedItem(item)
                itemsArray.append(.tagged(CBOR.Tag(rawValue: 24), .byteString(itemCBOR)))
            }
            nameSpacesMap[.utf8String(namespace)] = .array(itemsArray)
        }
        issuerSignedMap[.utf8String("nameSpaces")] = .map(nameSpacesMap)

        // issuerAuth (COSE_Sign1 - just store as bytes for workshop)
        issuerSignedMap[.utf8String("issuerAuth")] = .byteString(Array(mdoc.issuerSigned.issuerAuth))

        map[.utf8String("issuerSigned")] = .map(issuerSignedMap)

        // deviceSigned (optional)
        if let deviceSigned = mdoc.deviceSigned {
            var deviceSignedMap: [CBOR: CBOR] = [:]
            deviceSignedMap[.utf8String("nameSpaces")] = .byteString(Array(deviceSigned.nameSpaces))

            var deviceAuthMap: [CBOR: CBOR] = [:]
            if let mac = deviceSigned.deviceAuth.deviceMac {
                deviceAuthMap[.utf8String("deviceMac")] = .byteString(Array(mac))
            }
            if let sig = deviceSigned.deviceAuth.deviceSignature {
                deviceAuthMap[.utf8String("deviceSignature")] = .byteString(Array(sig))
            }
            deviceSignedMap[.utf8String("deviceAuth")] = .map(deviceAuthMap)

            map[.utf8String("deviceSigned")] = .map(deviceSignedMap)
        }

        let cbor = CBOR.map(map)
        return Data(cbor.encode())
    }

    /// Encode an IssuerSignedItem to CBOR
    private func encodeIssuerSignedItem(_ item: IssuerSignedItem) -> [UInt8] {
        var map: [CBOR: CBOR] = [:]

        map[.utf8String("digestID")] = .unsignedInt(UInt64(item.digestID))
        map[.utf8String("random")] = .byteString(Array(item.random))
        map[.utf8String("elementIdentifier")] = .utf8String(item.elementIdentifier)
        map[.utf8String("elementValue")] = encodeToCBOR(item.elementValue)

        return CBOR.map(map).encode()
    }

    /// Encode any Swift value to CBOR
    private func encodeToCBOR(_ value: Any) -> CBOR {
        switch value {
        case let boolVal as Bool:
            return .boolean(boolVal)
        case let intVal as Int:
            if intVal >= 0 {
                return .unsignedInt(UInt64(intVal))
            } else {
                return .negativeInt(UInt64(-intVal - 1))
            }
        case let stringVal as String:
            return .utf8String(stringVal)
        case let dataVal as Data:
            return .byteString(Array(dataVal))
        case let arrayVal as [Any]:
            return .array(arrayVal.map { encodeToCBOR($0) })
        case let dictVal as [String: Any]:
            var map: [CBOR: CBOR] = [:]
            for (key, val) in dictVal {
                map[.utf8String(key)] = encodeToCBOR(val)
            }
            return .map(map)
        default:
            return .utf8String(String(describing: value))
        }
    }

    /// Encode a DeviceRequest to CBOR format
    func encode(request: DeviceRequest) -> Data {
        var map: [CBOR: CBOR] = [:]

        map[.utf8String("version")] = .utf8String(request.version)

        var docRequestsArray: [CBOR] = []
        for docRequest in request.docRequests {
            var docRequestMap: [CBOR: CBOR] = [:]

            // itemsRequest
            var itemsRequestMap: [CBOR: CBOR] = [:]
            itemsRequestMap[.utf8String("docType")] = .utf8String(docRequest.itemsRequest.docType)

            var nameSpacesMap: [CBOR: CBOR] = [:]
            for (namespace, elements) in docRequest.itemsRequest.nameSpaces {
                var elementsMap: [CBOR: CBOR] = [:]
                for (elementId, retain) in elements {
                    elementsMap[.utf8String(elementId)] = .boolean(retain)
                }
                nameSpacesMap[.utf8String(namespace)] = .map(elementsMap)
            }
            itemsRequestMap[.utf8String("nameSpaces")] = .map(nameSpacesMap)

            docRequestMap[.utf8String("itemsRequest")] = .map(itemsRequestMap)

            if let readerAuth = docRequest.readerAuth {
                docRequestMap[.utf8String("readerAuth")] = .byteString(Array(readerAuth))
            }

            docRequestsArray.append(.map(docRequestMap))
        }
        map[.utf8String("docRequests")] = .array(docRequestsArray)

        let cbor = CBOR.map(map)
        return Data(cbor.encode())
    }

    /// Encode a DeviceResponse to CBOR format
    func encode(response: DeviceResponse) -> Data {
        var map: [CBOR: CBOR] = [:]

        map[.utf8String("version")] = .utf8String(response.version)
        map[.utf8String("status")] = .unsignedInt(UInt64(response.status))

        if let documents = response.documents {
            var docsArray: [CBOR] = []
            for doc in documents {
                var docMap: [CBOR: CBOR] = [:]
                docMap[.utf8String("docType")] = .utf8String(doc.docType)

                // Encode issuerSigned
                var issuerSignedMap: [CBOR: CBOR] = [:]
                var nameSpacesMap: [CBOR: CBOR] = [:]
                for (namespace, items) in doc.issuerSigned.nameSpaces {
                    var itemsArray: [CBOR] = []
                    for item in items {
                        let itemCBOR = encodeIssuerSignedItem(item)
                        itemsArray.append(.tagged(CBOR.Tag(rawValue: 24), .byteString(itemCBOR)))
                    }
                    nameSpacesMap[.utf8String(namespace)] = .array(itemsArray)
                }
                issuerSignedMap[.utf8String("nameSpaces")] = .map(nameSpacesMap)
                issuerSignedMap[.utf8String("issuerAuth")] = .byteString(Array(doc.issuerSigned.issuerAuth))
                docMap[.utf8String("issuerSigned")] = .map(issuerSignedMap)

                // Encode deviceSigned
                var deviceSignedMap: [CBOR: CBOR] = [:]
                deviceSignedMap[.utf8String("nameSpaces")] = .byteString(Array(doc.deviceSigned.nameSpaces))
                var deviceAuthMap: [CBOR: CBOR] = [:]
                if let mac = doc.deviceSigned.deviceAuth.deviceMac {
                    deviceAuthMap[.utf8String("deviceMac")] = .byteString(Array(mac))
                }
                if let sig = doc.deviceSigned.deviceAuth.deviceSignature {
                    deviceAuthMap[.utf8String("deviceSignature")] = .byteString(Array(sig))
                }
                deviceSignedMap[.utf8String("deviceAuth")] = .map(deviceAuthMap)
                docMap[.utf8String("deviceSigned")] = .map(deviceSignedMap)

                docsArray.append(.map(docMap))
            }
            map[.utf8String("documents")] = .array(docsArray)
        }

        let cbor = CBOR.map(map)
        return Data(cbor.encode())
    }

    /// Encode a DeviceEngagement to CBOR format
    func encode(engagement: DeviceEngagement) -> Data {
        // DeviceEngagement is encoded with numeric keys per ISO 18013-5
        var map: [CBOR: CBOR] = [:]

        // 0 = version
        map[.unsignedInt(0)] = .utf8String(engagement.version)

        // 1 = security
        var securityArray: [CBOR] = []
        securityArray.append(.unsignedInt(UInt64(engagement.security.cipherSuiteIdentifier)))
        securityArray.append(.byteString(Array(engagement.security.deviceEngagementKey)))
        map[.unsignedInt(1)] = .array(securityArray)

        // 2 = deviceRetrievalMethods
        var methodsArray: [CBOR] = []
        for method in engagement.deviceRetrievalMethods {
            var methodArray: [CBOR] = []
            methodArray.append(.unsignedInt(UInt64(method.type)))
            methodArray.append(.unsignedInt(UInt64(method.version)))

            // Options map
            var optionsMap: [CBOR: CBOR] = [:]
            if let peripheral = method.options.peripheralServerMode {
                optionsMap[.unsignedInt(0)] = .boolean(peripheral)
            }
            if let central = method.options.centralClientMode {
                optionsMap[.unsignedInt(1)] = .boolean(central)
            }
            if let uuid = method.options.peripheralServerUUID {
                optionsMap[.unsignedInt(10)] = .utf8String(uuid)
            }
            if let uuid = method.options.centralClientUUID {
                optionsMap[.unsignedInt(11)] = .utf8String(uuid)
            }
            methodArray.append(.map(optionsMap))

            methodsArray.append(.array(methodArray))
        }
        map[.unsignedInt(2)] = .array(methodsArray)

        let cbor = CBOR.map(map)
        return Data(cbor.encode())
    }

    // MARK: - CBOR Decoding

    /// Decode CBOR data to an mdoc
    func decodeMDoc(from data: Data) -> MDoc? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor else {
            return nil
        }

        // Extract docType
        guard case .utf8String(let docType) = map[.utf8String("docType")] else {
            return nil
        }

        // Extract issuerSigned
        guard case .map(let issuerSignedMap) = map[.utf8String("issuerSigned")] else {
            return nil
        }

        // Parse nameSpaces
        var nameSpaces: [String: [IssuerSignedItem]] = [:]
        if case .map(let nsMap) = issuerSignedMap[.utf8String("nameSpaces")] {
            for (nsKey, nsValue) in nsMap {
                guard case .utf8String(let namespace) = nsKey,
                      case .array(let itemsArray) = nsValue else {
                    continue
                }

                var items: [IssuerSignedItem] = []
                for itemCBOR in itemsArray {
                    if case .tagged(_, let inner) = itemCBOR,
                       case .byteString(let itemBytes) = inner,
                       let item = decodeIssuerSignedItem(Data(itemBytes)) {
                        items.append(item)
                    }
                }
                nameSpaces[namespace] = items
            }
        }

        // Parse issuerAuth
        var issuerAuth = Data()
        if case .byteString(let authBytes) = issuerSignedMap[.utf8String("issuerAuth")] {
            issuerAuth = Data(authBytes)
        }

        let issuerSigned = IssuerSigned(nameSpaces: nameSpaces, issuerAuth: issuerAuth)

        // Parse deviceSigned (optional)
        var deviceSigned: DeviceSigned? = nil
        if case .map(let deviceSignedMap) = map[.utf8String("deviceSigned")] {
            var dsNameSpaces = Data()
            if case .byteString(let nsBytes) = deviceSignedMap[.utf8String("nameSpaces")] {
                dsNameSpaces = Data(nsBytes)
            }

            var deviceMac: Data? = nil
            var deviceSignature: Data? = nil
            if case .map(let authMap) = deviceSignedMap[.utf8String("deviceAuth")] {
                if case .byteString(let macBytes) = authMap[.utf8String("deviceMac")] {
                    deviceMac = Data(macBytes)
                }
                if case .byteString(let sigBytes) = authMap[.utf8String("deviceSignature")] {
                    deviceSignature = Data(sigBytes)
                }
            }

            deviceSigned = DeviceSigned(
                nameSpaces: dsNameSpaces,
                deviceAuth: DeviceAuth(deviceMac: deviceMac, deviceSignature: deviceSignature)
            )
        }

        return MDoc(docType: docType, issuerSigned: issuerSigned, deviceSigned: deviceSigned)
    }

    /// Decode an IssuerSignedItem from CBOR bytes
    private func decodeIssuerSignedItem(_ data: Data) -> IssuerSignedItem? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor else {
            return nil
        }

        guard case .unsignedInt(let digestID) = map[.utf8String("digestID")],
              case .byteString(let random) = map[.utf8String("random")],
              case .utf8String(let elementIdentifier) = map[.utf8String("elementIdentifier")] else {
            return nil
        }

        let elementValue = decodeFromCBOR(map[.utf8String("elementValue")])

        return IssuerSignedItem(
            digestID: Int(digestID),
            random: Data(random),
            elementIdentifier: elementIdentifier,
            elementValue: elementValue ?? "null"
        )
    }

    /// Decode CBOR value to Swift value
    private func decodeFromCBOR(_ cbor: CBOR?) -> Any? {
        guard let cbor = cbor else { return nil }

        switch cbor {
        case .boolean(let val):
            return val
        case .unsignedInt(let val):
            return Int(val)
        case .negativeInt(let val):
            return -Int(val) - 1
        case .utf8String(let val):
            return val
        case .byteString(let val):
            return Data(val)
        case .array(let arr):
            return arr.compactMap { decodeFromCBOR($0) }
        case .map(let map):
            var dict: [String: Any] = [:]
            for (key, value) in map {
                if case .utf8String(let keyStr) = key {
                    dict[keyStr] = decodeFromCBOR(value)
                }
            }
            return dict
        default:
            return nil
        }
    }

    /// Decode CBOR data to a DeviceRequest
    func decodeRequest(from data: Data) -> DeviceRequest? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor else {
            return nil
        }

        guard case .utf8String(let version) = map[.utf8String("version")],
              case .array(let docRequestsArray) = map[.utf8String("docRequests")] else {
            return nil
        }

        var docRequests: [DocRequest] = []
        for drCBOR in docRequestsArray {
            guard case .map(let drMap) = drCBOR,
                  case .map(let irMap) = drMap[.utf8String("itemsRequest")],
                  case .utf8String(let docType) = irMap[.utf8String("docType")],
                  case .map(let nsMap) = irMap[.utf8String("nameSpaces")] else {
                continue
            }

            var nameSpaces: [String: [String: Bool]] = [:]
            for (nsKey, nsValue) in nsMap {
                guard case .utf8String(let namespace) = nsKey,
                      case .map(let elementsMap) = nsValue else {
                    continue
                }

                var elements: [String: Bool] = [:]
                for (elemKey, elemValue) in elementsMap {
                    if case .utf8String(let elemId) = elemKey,
                       case .boolean(let retain) = elemValue {
                        elements[elemId] = retain
                    }
                }
                nameSpaces[namespace] = elements
            }

            var readerAuth: Data? = nil
            if case .byteString(let authBytes) = drMap[.utf8String("readerAuth")] {
                readerAuth = Data(authBytes)
            }

            let itemsRequest = ItemsRequest(docType: docType, nameSpaces: nameSpaces)
            docRequests.append(DocRequest(itemsRequest: itemsRequest, readerAuth: readerAuth))
        }

        return DeviceRequest(version: version, docRequests: docRequests)
    }

    /// Decode CBOR data to a DeviceResponse
    func decodeResponse(from data: Data) -> DeviceResponse? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor else {
            return nil
        }

        guard case .utf8String(let version) = map[.utf8String("version")],
              case .unsignedInt(let status) = map[.utf8String("status")] else {
            return nil
        }

        var documents: [Document]? = nil
        if case .array(let docsArray) = map[.utf8String("documents")] {
            var docs: [Document] = []
            for docCBOR in docsArray {
                guard case .map(let docMap) = docCBOR,
                      case .utf8String(let docType) = docMap[.utf8String("docType")],
                      case .map(let issuerSignedMap) = docMap[.utf8String("issuerSigned")],
                      case .map(let deviceSignedMap) = docMap[.utf8String("deviceSigned")] else {
                    continue
                }

                // Parse issuerSigned
                var nameSpaces: [String: [IssuerSignedItem]] = [:]
                if case .map(let nsMap) = issuerSignedMap[.utf8String("nameSpaces")] {
                    for (nsKey, nsValue) in nsMap {
                        guard case .utf8String(let namespace) = nsKey,
                              case .array(let itemsArray) = nsValue else {
                            continue
                        }
                        var items: [IssuerSignedItem] = []
                        for itemCBOR in itemsArray {
                            if case .tagged(_, let inner) = itemCBOR,
                               case .byteString(let itemBytes) = inner,
                               let item = decodeIssuerSignedItem(Data(itemBytes)) {
                                items.append(item)
                            }
                        }
                        nameSpaces[namespace] = items
                    }
                }

                var issuerAuth = Data()
                if case .byteString(let authBytes) = issuerSignedMap[.utf8String("issuerAuth")] {
                    issuerAuth = Data(authBytes)
                }

                let issuerSigned = IssuerSigned(nameSpaces: nameSpaces, issuerAuth: issuerAuth)

                // Parse deviceSigned
                var dsNameSpaces = Data()
                if case .byteString(let nsBytes) = deviceSignedMap[.utf8String("nameSpaces")] {
                    dsNameSpaces = Data(nsBytes)
                }

                var deviceMac: Data? = nil
                var deviceSignature: Data? = nil
                if case .map(let authMap) = deviceSignedMap[.utf8String("deviceAuth")] {
                    if case .byteString(let macBytes) = authMap[.utf8String("deviceMac")] {
                        deviceMac = Data(macBytes)
                    }
                    if case .byteString(let sigBytes) = authMap[.utf8String("deviceSignature")] {
                        deviceSignature = Data(sigBytes)
                    }
                }

                let deviceSigned = DeviceSigned(
                    nameSpaces: dsNameSpaces,
                    deviceAuth: DeviceAuth(deviceMac: deviceMac, deviceSignature: deviceSignature)
                )

                docs.append(Document(
                    docType: docType,
                    issuerSigned: issuerSigned,
                    deviceSigned: deviceSigned,
                    errors: nil
                ))
            }
            documents = docs
        }

        return DeviceResponse(
            version: version,
            documents: documents,
            documentErrors: nil,
            status: Int(status)
        )
    }

    /// Decode CBOR data to a DeviceEngagement
    func decodeEngagement(from data: Data) -> DeviceEngagement? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor else {
            return nil
        }

        guard case .utf8String(let version) = map[.unsignedInt(0)],
              case .array(let securityArray) = map[.unsignedInt(1)],
              securityArray.count >= 2,
              case .unsignedInt(let cipherSuite) = securityArray[0],
              case .byteString(let keyBytes) = securityArray[1] else {
            return nil
        }

        let security = Security(
            cipherSuiteIdentifier: Int(cipherSuite),
            deviceEngagementKey: Data(keyBytes)
        )

        var deviceRetrievalMethods: [DeviceRetrievalMethod] = []
        if case .array(let methodsArray) = map[.unsignedInt(2)] {
            for methodCBOR in methodsArray {
                guard case .array(let methodArray) = methodCBOR,
                      methodArray.count >= 3,
                      case .unsignedInt(let type) = methodArray[0],
                      case .unsignedInt(let methodVersion) = methodArray[1],
                      case .map(let optionsMap) = methodArray[2] else {
                    continue
                }

                var peripheralServerMode: Bool? = nil
                var centralClientMode: Bool? = nil
                var peripheralServerUUID: String? = nil
                var centralClientUUID: String? = nil

                if case .boolean(let val) = optionsMap[.unsignedInt(0)] {
                    peripheralServerMode = val
                }
                if case .boolean(let val) = optionsMap[.unsignedInt(1)] {
                    centralClientMode = val
                }
                if case .utf8String(let val) = optionsMap[.unsignedInt(10)] {
                    peripheralServerUUID = val
                }
                if case .utf8String(let val) = optionsMap[.unsignedInt(11)] {
                    centralClientUUID = val
                }

                let options = RetrievalOptions(
                    peripheralServerMode: peripheralServerMode,
                    centralClientMode: centralClientMode,
                    peripheralServerUUID: peripheralServerUUID,
                    centralClientUUID: centralClientUUID,
                    bleDeviceAddress: nil
                )

                deviceRetrievalMethods.append(DeviceRetrievalMethod(
                    type: Int(type),
                    version: Int(methodVersion),
                    options: options
                ))
            }
        }

        return DeviceEngagement(
            version: version,
            security: security,
            deviceRetrievalMethods: deviceRetrievalMethods
        )
    }

    // MARK: - MSO (Mobile Security Object)

    /// Encode a Mobile Security Object to CBOR
    /// - Parameters:
    ///   - docType: The document type (e.g., "org.iso.18013.5.1.mDL")
    ///   - nameSpaces: Map of namespace to array of IssuerSignedItems
    ///   - validityInfo: The validity period for the MSO
    /// - Returns: CBOR-encoded MSO data
    func encodeMSO(
        docType: String,
        nameSpaces: [String: [IssuerSignedItem]],
        validityInfo: ValidityInfo
    ) -> Data {
        var msoMap: [CBOR: CBOR] = [:]

        msoMap[.utf8String("version")] = .utf8String("1.0")
        msoMap[.utf8String("digestAlgorithm")] = .utf8String("SHA-256")
        msoMap[.utf8String("docType")] = .utf8String(docType)

        // Build valueDigests: namespace → (digestID → SHA-256 hash)
        var valueDigestsMap: [CBOR: CBOR] = [:]
        for (namespace, items) in nameSpaces {
            var digestsMap: [CBOR: CBOR] = [:]
            for item in items {
                // ISO 18013-5: hash the Tag 24-wrapped CBOR encoding of each IssuerSignedItem
                let itemBytes = encodeIssuerSignedItem(item)
                let tagged = CBOR.tagged(CBOR.Tag(rawValue: 24), .byteString(itemBytes))
                let taggedBytes = Data(tagged.encode())
                let hash = CryptoService.shared.sha256(taggedBytes)
                digestsMap[.unsignedInt(UInt64(item.digestID))] = .byteString(Array(hash))
            }
            valueDigestsMap[.utf8String(namespace)] = .map(digestsMap)
        }
        msoMap[.utf8String("valueDigests")] = .map(valueDigestsMap)

        // validityInfo
        var validityMap: [CBOR: CBOR] = [:]
        validityMap[.utf8String("signed")] = .utf8String(validityInfo.signed)
        validityMap[.utf8String("validFrom")] = .utf8String(validityInfo.validFrom)
        validityMap[.utf8String("validUntil")] = .utf8String(validityInfo.validUntil)
        msoMap[.utf8String("validityInfo")] = .map(validityMap)

        return Data(CBOR.map(msoMap).encode())
    }

    /// Decode a Mobile Security Object from CBOR data
    /// - Parameter data: CBOR-encoded MSO
    /// - Returns: Decoded MobileSecurityObject, or nil if invalid
    func decodeMSO(from data: Data) -> MobileSecurityObject? {
        guard let cbor = try? CBOR.decode(Array(data)),
              case .map(let map) = cbor else {
            return nil
        }

        guard case .utf8String(let version) = map[.utf8String("version")],
              case .utf8String(let digestAlgorithm) = map[.utf8String("digestAlgorithm")],
              case .utf8String(let docType) = map[.utf8String("docType")],
              case .map(let valueDigestsMap) = map[.utf8String("valueDigests")],
              case .map(let validityMap) = map[.utf8String("validityInfo")] else {
            return nil
        }

        // Parse valueDigests
        var valueDigests: [String: [Int: Data]] = [:]
        for (nsKey, nsValue) in valueDigestsMap {
            guard case .utf8String(let namespace) = nsKey,
                  case .map(let digestsMap) = nsValue else {
                continue
            }
            var digests: [Int: Data] = [:]
            for (idKey, hashValue) in digestsMap {
                guard case .unsignedInt(let digestID) = idKey,
                      case .byteString(let hashBytes) = hashValue else {
                    continue
                }
                digests[Int(digestID)] = Data(hashBytes)
            }
            valueDigests[namespace] = digests
        }

        // Parse validityInfo
        guard case .utf8String(let signed) = validityMap[.utf8String("signed")],
              case .utf8String(let validFrom) = validityMap[.utf8String("validFrom")],
              case .utf8String(let validUntil) = validityMap[.utf8String("validUntil")] else {
            return nil
        }

        return MobileSecurityObject(
            version: version,
            digestAlgorithm: digestAlgorithm,
            valueDigests: valueDigests,
            docType: docType,
            validityInfo: ValidityInfo(signed: signed, validFrom: validFrom, validUntil: validUntil)
        )
    }

    // MARK: - Helper Methods

    /// Extract specific attributes from an mdoc
    func extractAttributes(from mdoc: MDoc, attributes: [String]) -> [String: Any] {
        var result: [String: Any] = [:]

        for (_, items) in mdoc.issuerSigned.nameSpaces {
            for item in items {
                if attributes.contains(item.elementIdentifier) {
                    result[item.elementIdentifier] = item.elementValue
                }
            }
        }

        return result
    }

    /// Create a selective disclosure response from an mdoc
    func createSelectiveResponse(from mdoc: MDoc, for request: DeviceRequest) -> MDoc {
        guard let docRequest = request.docRequests.first else {
            return mdoc
        }

        // Get requested element identifiers
        var requestedElements = Set<String>()
        for (_, elements) in docRequest.itemsRequest.nameSpaces {
            for (elementId, _) in elements {
                requestedElements.insert(elementId)
            }
        }

        // Filter nameSpaces to only include requested items
        var filteredNameSpaces: [String: [IssuerSignedItem]] = [:]
        for (namespace, items) in mdoc.issuerSigned.nameSpaces {
            let filteredItems = items.filter { requestedElements.contains($0.elementIdentifier) }
            if !filteredItems.isEmpty {
                filteredNameSpaces[namespace] = filteredItems
            }
        }

        let filteredIssuerSigned = IssuerSigned(
            nameSpaces: filteredNameSpaces,
            issuerAuth: mdoc.issuerSigned.issuerAuth
        )

        // Create device signature for the response
        let deviceAuth = DeviceAuth(
            deviceMac: nil,
            deviceSignature: CryptoService.shared.devicePublicKeyData
        )

        let deviceSigned = DeviceSigned(
            nameSpaces: Data(),
            deviceAuth: deviceAuth
        )

        return MDoc(
            docType: mdoc.docType,
            issuerSigned: filteredIssuerSigned,
            deviceSigned: deviceSigned
        )
    }
}

// MARK: - CBOR Diagnostic Utilities

extension CBORService {
    /// Convert CBOR data to a human-readable diagnostic string
    func diagnosticString(from data: Data) -> String {
        guard let cbor = try? CBOR.decode(Array(data)) else {
            return "Invalid CBOR data"
        }
        return describeCBOR(cbor, indent: 0)
    }

    private func describeCBOR(_ cbor: CBOR, indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)

        switch cbor {
        case .unsignedInt(let val):
            return "\(val)"
        case .negativeInt(let val):
            return "-\(val + 1)"
        case .byteString(let bytes):
            return "h'\(bytes.prefix(8).map { String(format: "%02x", $0) }.joined())...'"
        case .utf8String(let str):
            return "\"\(str)\""
        case .array(let arr):
            if arr.isEmpty { return "[]" }
            var result = "[\n"
            for (i, item) in arr.enumerated() {
                result += "\(prefix)  \(describeCBOR(item, indent: indent + 1))"
                if i < arr.count - 1 { result += "," }
                result += "\n"
            }
            result += "\(prefix)]"
            return result
        case .map(let map):
            if map.isEmpty { return "{}" }
            var result = "{\n"
            let keys = Array(map.keys)
            for (i, key) in keys.enumerated() {
                let value = map[key]!
                result += "\(prefix)  \(describeCBOR(key, indent: indent + 1)): \(describeCBOR(value, indent: indent + 1))"
                if i < keys.count - 1 { result += "," }
                result += "\n"
            }
            result += "\(prefix)}"
            return result
        case .tagged(let tag, let item):
            return "\(tag.rawValue)(\(describeCBOR(item, indent: indent)))"
        case .boolean(let val):
            return val ? "true" : "false"
        case .null:
            return "null"
        case .undefined:
            return "undefined"
        case .simple(let val):
            return "simple(\(val))"
        case .half(let val):
            return String(val)
        case .float(let val):
            return String(val)
        case .double(let val):
            return String(val)
        case .break:
            return "break"
        case .date(let date):
            return "date(\(date))"
        }
    }
}
