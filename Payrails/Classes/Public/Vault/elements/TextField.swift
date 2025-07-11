/*
 * Copyright (c) 2022 Skyflow
 */

/*
 *Implementation of SkyflowInputField which
 *is a combination of [Label, TextField, ValidationErrorMessage]
 */

import Foundation

#if os(iOS)
import UIKit
#endif


public class TextField: SkyflowElement, Element, BaseElement {
    var onBeginEditing: (() -> Void)?
    var onEndEditing: (() -> Void)?
    var onFocusIsTrue: (() -> Void)?
    internal var textField = FormatTextField(frame: .zero)
    internal var errorMessage = PaddingLabel(frame: .zero)
    internal var isDirty = false
    internal var validationRules = ValidationSet()
    internal var userValidationRules = ValidationSet()
    internal var stackView = UIStackView()
    internal var textFieldLabel = PaddingLabel(frame: .zero)
    internal var hasBecomeResponder: Bool = false
    internal var copyIconImageView: UIImageView?
    internal var cardIconAlignment: CardIconAlignment = .left
    internal var rightViewForIcons = UIView()
    internal var copyContainerView = UIView()
    internal var cardIconContainerView = UIView()
    private var customErrorMessage: String?
    
    internal var textFieldDelegate: UITextFieldDelegate? = nil
    
    internal var errorTriggered: Bool = false
    
    internal var isErrorMessageShowing: Bool {
        return self.errorMessage.alpha == 1.0
    }

    internal var listCardTypes: [CardType]?
    internal var dropdownButton = UIButton()
    internal var selectedCardBrand: CardType? = nil

    internal var uuid: String = ""
    
    internal var textFieldCornerRadius: CGFloat {
        get {
            return textField.layer.cornerRadius
        }
        set {
            textField.layer.cornerRadius = newValue
            textField.layer.masksToBounds = newValue > 0
        }
    }
    
    internal var textFieldBorderWidth: CGFloat {
        get {
            return textField.layer.borderWidth
        }
        set {
            textField.layer.borderWidth = newValue
        }
    }
    
    internal var textFieldBorderColor: UIColor? {
        get {
            guard let cgcolor = textField.layer.borderColor else {
                return nil
            }
            return UIColor(cgColor: cgcolor)
        }
        set {
            textField.layer.borderColor = newValue?.cgColor
        }
    }
    
    internal var textFieldPadding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
        didSet { setMainPaddings() }
    }
    
    internal override var state: State {
        return StateforText(tf: self)
    }
    
    var maxLength: Int?
    
    override init(input: CollectElementInput, options: CollectElementOptions, contextOptions: ContextOptions, elements: [TextField]? = nil) {
        super.init(input: input, options: options, contextOptions: contextOptions, elements: elements ?? [])
        self.customErrorMessage = input.customErrorMessage
        self.userValidationRules.append(input.validations)
        self.textFieldDelegate = TextFieldValidationDelegate(collectField: self)
        self.textField.delegate = self.textFieldDelegate!
        setFormatPattern()
        setupField()
        let formatNotSupportedElements = [ElementType.CARDHOLDER_NAME, ElementType.EXPIRATION_MONTH, ElementType.CVV, ElementType.PIN]
        if(formatNotSupportedElements.contains(fieldType)) {
            var context = self.contextOptions
            context?.interface = .COLLECT_CONTAINER
            context?.logLevel = .WARN
            if(options.translation != nil || options.format != "mm/yy"){
                Log.warn(message: .FORMAT_AND_TRANSLATION, values: [fieldType.name], contextOptions: context!)
            }
        }
    }
    
    internal func addValidations() {
        if self.fieldType == .EXPIRATION_DATE {
            self.addDateValidations()
        } else if self.fieldType == .EXPIRATION_YEAR {
            self.addYearValidations()
        } else if self.fieldType == .EXPIRATION_MONTH {
            self.addMonthValidations()
        }
    }
    
    internal func addDateValidations() {
        let defaultFormat = "mm/yy"
        let supportedFormats = [defaultFormat, "mm/yyyy", "yy/mm", "yyyy/mm"]
        if !supportedFormats.contains(self.options.format.lowercased()) {
            var context = self.contextOptions
            context?.interface = .COLLECT_CONTAINER
            Log.warn(message: .INVALID_EXPIRYDATE_FORMAT, values: [self.options.format.lowercased()], contextOptions: context!)
            self.options.format = defaultFormat
        }
        let expiryDateRule = SkyflowValidateCardExpirationDate(format: options.format, error: SkyflowValidationErrorType.expirationDate.rawValue)
        self.validationRules.append(ValidationSet(rules: [expiryDateRule]))
    }
    
    internal func addMonthValidations() {
        let monthRule = SkyflowValidateExpirationMonth(error: SkyflowValidationErrorType.expirationMonth.rawValue)
        self.validationRules.append(ValidationSet(rules: [monthRule]))
    }
    
    internal func addYearValidations() {
        var format = "yyyy"
        if self.options.format.lowercased() == "yy" {
            format = "yy"
        }
        
        let yearRule = SkyflowValidateExpirationYear(format: format, error: SkyflowValidationErrorType.expirationYear.rawValue)
        self.validationRules.append(ValidationSet(rules: [yearRule]))
    }
    
    internal func setFormatPattern() {
        switch fieldType {
        case .CARD_NUMBER:
            let cardType = CardType.forCardNumber(cardNumber: self.actualValue).instance
            if(options.format.uppercased() == "XXXX-XXXX-XXXX-XXXX"){
              self.textField.formatPattern = cardType.formatPattern.replacingOccurrences(of: " ", with: "-")
            } else {
                self.textField.formatPattern = cardType.formatPattern

            }
        case .EXPIRATION_DATE:
            self.textField.formatPattern = self.options.format.lowercased().replacingOccurrences(of: "\\w", with: "#", options: .regularExpression)
        default:
            if let instance = fieldType.instance {
                self.textField.formatPattern = instance.formatPattern
            }
        }
    }
    
    required internal init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    internal func isMounted() -> Bool {
        var flag = false
        if Thread.isMainThread {
            flag = self.window != nil
        } else {
            DispatchQueue.main.sync {
                flag = self.window != nil
            }
        }
        return flag
    }
    
    
    internal var hasFocus = false
    
    internal var onChangeHandler: (([String: Any]) -> Void)?
    internal var onBlurHandler: (([String: Any]) -> Void)?
    internal var onReadyHandler: (([String: Any]) -> Void)?
    internal var onFocusHandler: (([String: Any]) -> Void)?
    internal var onSubmitHandler: (() -> Void)?

    
    override func getOutput() -> String? {
        return textField.getTextwithFormatPattern
    }
    
    internal var actualValue: String = ""
    
    internal func getValue() -> String {
        return actualValue
    }
    
    
    internal func getOutputTextwithoutFormatPattern() -> String? {
        return textField.getSecureRawText
    }
    
    public func update(update: CollectElementInput){
        collectInput.placeholder = update.placeholder
        if update.column.isEmpty != true {
            collectInput.column = update.column
        }
        if update.table.isEmpty != true {
            collectInput.table = update.table
        }
        if update.column.isEmpty != true {
            collectInput.column = update.column
        }
        if update.label.isEmpty != true {
            collectInput.label = update.label
        }
        if update.validations.rules.isEmpty != true {
            collectInput.validations = update.validations
        }
         updateStyle(update.inputStyles.base, &collectInput.inputStyles.base)
         updateStyle(update.inputStyles.complete, &collectInput.inputStyles.complete)
         updateStyle(update.inputStyles.empty, &collectInput.inputStyles.empty)
         updateStyle(update.inputStyles.focus, &collectInput.inputStyles.focus)
         updateStyle(update.inputStyles.invalid, &collectInput.inputStyles.invalid)
         updateStyle(update.inputStyles.requiredAstrisk, &collectInput.inputStyles.invalid)

         updateStyle(update.labelStyles.base, &collectInput.labelStyles.base)
         updateStyle(update.labelStyles.complete, &collectInput.labelStyles.complete)
         updateStyle(update.labelStyles.empty, &collectInput.labelStyles.empty)
         updateStyle(update.labelStyles.focus, &collectInput.labelStyles.focus)
         updateStyle(update.labelStyles.invalid, &collectInput.labelStyles.invalid)
         updateStyle(update.labelStyles.requiredAstrisk, &collectInput.labelStyles.requiredAstrisk)
        
         updateStyle(update.errorTextStyles.base, &collectInput.errorTextStyles.base)
         updateStyle(update.errorTextStyles.complete, &collectInput.errorTextStyles.complete)
         updateStyle(update.errorTextStyles.empty, &collectInput.errorTextStyles.empty)
         updateStyle(update.errorTextStyles.focus, &collectInput.errorTextStyles.focus)
         updateStyle(update.errorTextStyles.invalid, &collectInput.errorTextStyles.invalid)
         updateStyle(update.errorTextStyles.requiredAstrisk, &collectInput.errorTextStyles.requiredAstrisk)
        
         updateStyle(update.iconStyles.base, &collectInput.iconStyles.base)
         updateStyle(update.iconStyles.complete, &collectInput.iconStyles.complete)
         updateStyle(update.iconStyles.empty, &collectInput.iconStyles.empty)
         updateStyle(update.iconStyles.focus, &collectInput.iconStyles.focus)
         updateStyle(update.iconStyles.invalid, &collectInput.iconStyles.invalid)
         updateStyle(update.iconStyles.requiredAstrisk, &collectInput.iconStyles.requiredAstrisk)

        setupField()
    }
    
    public func update(updateOptions: CollectElementOptions){
        if(updateOptions.cardMetaData != nil && self.fieldType == .CARD_NUMBER){
            self.options.cardMetaData = updateOptions.cardMetaData

            if let schemes = self.options.cardMetaData?["scheme"] as? [CardType] {
                if schemes.isEmpty {
                    selectedCardBrand = nil
                    listCardTypes = nil
                
                } else {
                    for _ in schemes {
                        listCardTypes = schemes
                        if let cardTypes = listCardTypes, cardTypes.count >= 2 {
                            getDropDownIcon()
                        }
                    }
                }
                let t = self.textField.secureText!.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
                let card = CardType.forCardNumber(cardNumber: t).instance
                updateImage(name: card.imageName, cardNumber: t)
            }
            let t = self.textField.secureText!.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
            let card = CardType.forCardNumber(cardNumber: t).instance
            updateImage(name: card.imageName, cardNumber: t)
        }
        
    }

    func updateStyle(_ source: Style?, _ destination: inout Style?) {
            guard let newStyle = source else { return }
            if destination == nil {
                destination = Style()
            }
        if (newStyle.borderColor != nil) {
            destination?.borderColor = newStyle.borderColor
        }
        if (newStyle.cornerRadius != nil){
            destination?.cornerRadius = newStyle.cornerRadius
        }
        if (newStyle.padding != nil){
            destination?.padding = newStyle.padding

        }
        if (newStyle.textAlignment != nil){
            destination?.textAlignment = newStyle.textAlignment

        }
        if (newStyle.borderWidth != nil){
            destination?.borderWidth = newStyle.borderWidth

        }
        if (newStyle.font != nil){
            destination?.font = newStyle.font

        }
        if (newStyle.width != nil){
            destination?.width = newStyle.width
        }
        if (newStyle.height != nil){
            destination?.height = newStyle.height

        }
        }
    
    public func setValue(value: String) {
        if(contextOptions.env == .DEV){
            if(self.fieldType == .INPUT_FIELD && !(options.format == "mm/yy" || options.format == "")){
                if(options.translation == nil){
                    options.translation = ["X": "[0-9]"]
                }
                for (key, value) in options.translation! {
                    if value == "" {
                        options.translation![key] = "(?:)"
                    }
                }
                let result =  self.textField.formatInput(input: value, format: options.format, translation: options.translation!)
                self.textField.secureText = result
                actualValue = result
            }else {
                actualValue = value
                
                self.textField.addAndFormatText(value)
            }
            textFieldDidChange(self.textField)

        } else {
            var context = self.contextOptions
            context?.interface = .COLLECT_CONTAINER
            Log.warn(message: .SET_VALUE_WARNING, values: [self.collectInput.type?.name ?? "collect"],contextOptions: context!)
        }
    }
    
    public func clearValue(){
        if(contextOptions.env == .DEV){
            actualValue = ""
            textField.secureText = ""
        } else {
            var context = self.contextOptions
            context?.interface = .COLLECT_CONTAINER
            Log.warn(message: .CLEAR_VALUE_WARNING, values: [self.collectInput.type?.name ?? "collect"],contextOptions: context!)
        }
    }
    
    override func setupField() {
        super.setupField()
        self.cardIconAlignment = collectInput.iconStyles.base?.cardIconAlignment ?? .left
        self.textField.placeholder = collectInput.placeholder
        
        updateInputStyle()
        if let instance = fieldType.instance {
            validationRules = instance.validation
            textField.keyboardType = instance.keyboardType
        }
        addValidations()
        if collectInput.inputStyles.base?.width != nil {
            NSLayoutConstraint.activate([
                self.textField.widthAnchor.constraint(equalToConstant: (collectInput.inputStyles.base?.width)!)
            ])

        }
        if collectInput.inputStyles.base?.height != nil {
            NSLayoutConstraint.activate([
                self.textField.heightAnchor.constraint(equalToConstant: (collectInput.inputStyles.base?.height)!)
            ])
        }
        if collectInput.errorTextStyles.base?.height != nil {
            NSLayoutConstraint.activate([
                self.errorMessage.heightAnchor.constraint(equalToConstant: (collectInput.errorTextStyles.base?.height)!)
            ])
        }
        if collectInput.errorTextStyles.base?.width != nil {
            NSLayoutConstraint.activate([
                self.errorMessage.widthAnchor.constraint(equalToConstant: (collectInput.errorTextStyles.base?.width)!)
            ])
        }
        if collectInput.labelStyles.base?.height != nil {
            NSLayoutConstraint.activate([
                self.textFieldLabel.heightAnchor.constraint(equalToConstant: (collectInput.labelStyles.base?.height)!)
            ])
        }
        if collectInput.labelStyles.base?.width != nil {
            NSLayoutConstraint.activate([
                self.textFieldLabel.widthAnchor.constraint(equalToConstant: (collectInput.labelStyles.base?.width)!)
            ])
        }
        
        self.textFieldLabel.textColor = collectInput.labelStyles.base?.textColor ?? .none
        self.textFieldLabel.font = collectInput.labelStyles.base?.font ?? .none
        self.textFieldLabel.textAlignment = collectInput.labelStyles.base?.textAlignment ?? .left
        self.textFieldLabel.insets = collectInput.labelStyles.base?.padding ?? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        self.errorMessage.textColor = collectInput.errorTextStyles.base?.textColor ?? .none
        self.errorMessage.font = collectInput.errorTextStyles.base?.font ?? .none
        self.errorMessage.textAlignment = collectInput.errorTextStyles.base?.textAlignment ?? .left
        self.errorMessage.insets = collectInput.errorTextStyles.base?.padding ?? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        if self.fieldType == .CARD_NUMBER, self.options.enableCardIcon {
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
            #if SWIFT_PACKAGE
            var image = UIImage(named: "Unknown-Card", in: Bundle.module, compatibleWith: nil)
            #else
            let frameworkBundle = Bundle(for: TextField.self)
            var bundleURL = frameworkBundle.resourceURL
            bundleURL!.appendPathComponent("Skyflow.bundle")
            let resourceBundle = Bundle(url: bundleURL!)
            var image = UIImage(named: "Unknown-Card", in: resourceBundle, compatibleWith: nil)
            #endif
            imageView.image = image
            imageView.contentMode = .center
            cardIconContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 20 , height: 24))
            cardIconContainerView.addSubview(imageView)
            
            if(cardIconAlignment == .left){
                textField.leftViewMode = UITextField.ViewMode.always
                textField.leftView = cardIconContainerView
            } else {
                rightViewForIcons.addSubview(cardIconContainerView)
                textField.rightViewMode =  UITextField.ViewMode.always
                textField.rightView = rightViewForIcons
            }
        } else if self.fieldType == .CARD_NUMBER, !self.options.enableCardIcon {
            cardIconContainerView.isHidden = true
        }
        if self.options.enableCopy {
            textField.rightViewMode =  UITextField.ViewMode.always
            addCopyIcon()
            if (self.fieldType == .CARD_NUMBER) {
                if self.options.enableCardIcon && cardIconAlignment == .left{
                    textField.rightView = copyContainerView
                    textField.rightView?.isHidden = true
                } else if self.options.enableCardIcon && cardIconAlignment == .right {
                    copyContainerView.isHidden = true
                    copyContainerView.frame = CGRect(x: 65, y: 6, width: 30, height: Int(copyContainerView.frame.height))
                    rightViewForIcons.addSubview(copyContainerView)
                } else {
                    textField.rightViewMode =  UITextField.ViewMode.always
                    copyContainerView.isHidden = true
                    textField.rightView = copyContainerView
                    cardIconContainerView.isHidden = true
                }
            } else {
                textField.rightView = copyContainerView
                textField.rightView?.isHidden = true
            }
        }

        
        if self.fieldType == .CARD_NUMBER {
            let t = self.textField.secureText!.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
            let card = CardType.forCardNumber(cardNumber: t).instance
            updateImage(name: card.imageName, cardNumber: t)
        }
        
        setFormatPattern()
        
    }
    
    private func addCopyIcon(){
        copyIconImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        #if SWIFT_PACKAGE
        let image = UIImage(named: "Copy-Icon", in: Bundle.module, compatibleWith: nil)
        #else
        let frameworkBundle = Bundle(for: TextField.self)
        var bundleURL = frameworkBundle.resourceURL
        bundleURL!.appendPathComponent("Skyflow.bundle")
        let resourceBundle = Bundle(url: bundleURL!)
        var image = UIImage(named: "Copy-Icon", in: resourceBundle, compatibleWith: nil)
        #endif
        copyIconImageView?.image = image
        copyIconImageView?.contentMode = .scaleAspectFit
        copyContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 24 , height: 24))
        copyContainerView.addSubview(copyIconImageView!)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyIconTapped(_:)))
        copyContainerView.isUserInteractionEnabled = true
        copyContainerView.addGestureRecognizer(tapGesture)
    }
    @objc private func copyIconTapped(_ sender: UITapGestureRecognizer) {
        // Copy text when the copy icon is tapped
        copy(sender)
    }
    @objc
    public override func copy(_ sender: Any?) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = actualValue
        #if SWIFT_PACKAGE
        let image = UIImage(named: "Success-Icon", in: Bundle.module, compatibleWith: nil)
        #else
        let frameworkBundle = Bundle(for: TextField.self)
        var bundleURL = frameworkBundle.resourceURL
        bundleURL!.appendPathComponent("Skyflow.bundle")
        let resourceBundle = Bundle(url: bundleURL!)
        var image = UIImage(named: "Success-Icon", in: resourceBundle, compatibleWith: nil)
        #endif
        copyIconImageView?.image = image

        // Reset the copy icon after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            #if SWIFT_PACKAGE
            let copyImage = UIImage(named: "Copy-Icon", in: Bundle.module, compatibleWith: nil)
            #else
            let frameworkBundle = Bundle(for: TextField.self)
            var bundleURL = frameworkBundle.resourceURL
            bundleURL!.appendPathComponent("Skyflow.bundle")
            let resourceBundle = Bundle(url: bundleURL!)
            var copyImage = UIImage(named: "Copy-Icon", in: resourceBundle, compatibleWith: nil)
            #endif
            self?.copyIconImageView?.image = copyImage
        }
            
    }
    internal func updateImage(name: String, cardNumber: String){
        var name = name
        if self.options.enableCardIcon == false {
            return
        }
        if (selectedCardBrand != nil && cardNumber.isEmpty) {
            selectedCardBrand = nil
        } else if (selectedCardBrand != nil ){
            name = selectedCardBrand?.instance.imageName ?? CardType.forCardNumber(cardNumber: cardNumber).instance.imageName
        }

        let imageView = UIImageView(frame: CGRect(x: 0, y: 5, width: 40 + (0), height: 24))
        #if SWIFT_PACKAGE
        let image = UIImage(named: name, in: Bundle.module, compatibleWith: nil)
        #else
        let frameworkBundle = Bundle(for: TextField.self)
        var bundleURL = frameworkBundle.resourceURL
        bundleURL!.appendPathComponent("Skyflow.bundle")
        let resourceBundle = Bundle(url: bundleURL!)
        let image = UIImage(named: name, in: resourceBundle, compatibleWith: nil)
        #endif
        imageView.image = image
        imageView.layer.cornerRadius = self.collectInput!.iconStyles.base?.cornerRadius ?? 0
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 40))
        containerView.addSubview(imageView)
        imageView.bounds = imageView.frame.inset(by: self.collectInput!.iconStyles.base?.padding ?? UIEdgeInsets(top: .zero, left: .zero, bottom: .zero, right: .zero))
        imageView.layer.borderColor = self.collectInput!.iconStyles.base?.borderColor?.cgColor
        imageView.layer.borderWidth = self.collectInput!.iconStyles.base?.borderWidth ?? 0
        imageView.layer.cornerRadius = self.collectInput!.iconStyles.base?.cornerRadius ?? 0
    
//        dropdownIcon.frame = CGRect(x: imageView.frame.width + 7, y: containerView.frame.height / 3, width: 12, height: 15)

        if (listCardTypes?.count == 0 || listCardTypes == nil) {
            selectedCardBrand = nil
            dropdownButton.isHidden = true
            dropdownButton.removeFromSuperview()
            imageView.center = containerView.center
        } else if (listCardTypes != nil){
            if (listCardTypes!.count >= 2){
                imageView.frame = CGRect(x: 0, y: 0, width: 40, height: 24)

                // uimenu code
                if #available(iOS 14.0, *) {
                    if (cardIconAlignment == .left){
                        textField.padding.left = 70
                    }
                    dropdownButton.frame = CGRect(x: imageView.frame.maxX + 10, y: (containerView.frame.height / 2) - 5, width: 12, height: 15)
                    imageView.center = CGPoint(x: containerView.frame.width / 2 - dropdownButton.frame.width / 2,
                                               y: containerView.frame.height / 2)
                    containerView.frame = CGRect(x: 0, y: 0, width: max(imageView.frame.maxX, dropdownButton.frame.maxX), height: 40)
                    containerView.addSubview(dropdownButton)
                }
            } else {
                if #available(iOS 14.0, *) {
                    dropdownButton.isHidden = true
                }
                if (cardIconAlignment == .left){
                    textField.padding.left = 60
                }

                imageView.center = containerView.center
            }
        }
        cardIconContainerView = containerView

        if self.options.enableCopy {
            if(cardIconAlignment == .left && self.options.enableCardIcon){
                textField.leftViewMode = .always
                textField.leftView = cardIconContainerView
            } else {
                cardIconContainerView.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
                cardIconContainerView.addSubview(copyContainerView)
                textField.rightView = cardIconContainerView
                textField.rightViewMode = .always
                
            }
        } else {
            if(cardIconAlignment == .left && self.options.enableCardIcon){
                textField.leftViewMode = .always
                textField.leftView = cardIconContainerView
            } else {
                if (dropdownButton.isHidden){
                    cardIconContainerView.frame = CGRect(x: 0, y: 0, width: containerView.frame.width + 5, height: 40)
                } else {
                    cardIconContainerView.frame = CGRect(x: 0, y: 0, width: containerView.frame.width + dropdownButton.frame.width + 5, height: 40)
                }
                textField.rightView = cardIconContainerView
                textField.rightViewMode = .always
            }
            
        }
    }
    
    private func getDropDownIcon(){
        if #available(iOS 14.0, *) {
            setUpMenuView()
            dropdownButton.frame = CGRect(x: 0, y: 0, width: 12, height: 15)
            #if SWIFT_PACKAGE
            dropdownButton.setImage(UIImage(named: "dropdown", in: Bundle.module, compatibleWith: nil), for: .normal)
            #else
            let frameworkBundle = Bundle(for: TextField.self)
            var bundleURL = frameworkBundle.resourceURL
            bundleURL!.appendPathComponent("Skyflow.bundle")
            let resourceBundle = Bundle(url: bundleURL!)
            dropdownButton.setImage(UIImage(named: "dropdown", in: resourceBundle, compatibleWith: nil), for: .normal)
            #endif
            dropdownButton.isHidden = false
            dropdownButton.tintColor = .gray
        }
    }
    @available(iOS 14.0, *)
    internal func setUpMenuView() {
        let actionClosure: (UIAction) -> Void = { [weak self] action in
            guard let self = self else { return }
            
            if let matchingCardType = CardType.allCases.first(where: { $0.instance.defaultName == action.title }) {
                self.selectedCardBrand = matchingCardType
            }
            if self.fieldType == .CARD_NUMBER {
                let t = self.textField.secureText!.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
                let card = CardType.forCardNumber(cardNumber: t).instance
                self.updateImage(name: self.selectedCardBrand?.instance.imageName ?? card.imageName, cardNumber: t)
                self.onChangeHandler?((self.state as! StateforText).getStateForListener())
            }
            
            self.updateMenuView()
        }

        var menuChildren: [UIMenuElement] = []

        if let cardTypes = listCardTypes {
            for cardType in cardTypes {
                let state: UIMenuElement.State = (cardType.instance.defaultName == selectedCardBrand?.instance.defaultName) ? .on : .off
                let action = UIAction(title: cardType.instance.defaultName, state: state, handler: actionClosure)
                menuChildren.append(action)
            }
        }
        let menu = UIMenu(options: .displayInline, children: menuChildren)
        dropdownButton.menu = menu
        dropdownButton.showsMenuAsPrimaryAction = true
    }

    @available(iOS 14.0, *)
    internal func updateMenuView() {
        var updatedMenuChildren: [UIMenuElement] = []

        if let cardTypes = listCardTypes {
            for cardType in cardTypes {
                let state: UIMenuElement.State = (cardType.instance.defaultName == selectedCardBrand?.instance.defaultName) ? .on : .off
                let action = UIAction(title: cardType.instance.defaultName, state: state, handler: { [weak self] action in
                    guard let self = self else { return }
                    if let matchingCardType = CardType.allCases.first(where: { $0.instance.defaultName == action.title }) {
                        self.selectedCardBrand = matchingCardType
                    }
                    if self.fieldType == .CARD_NUMBER {
                        let t = self.textField.secureText!.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
                        let card = CardType.forCardNumber(cardNumber: t).instance
                        self.updateImage(name: self.selectedCardBrand?.instance.imageName ?? card.imageName, cardNumber: t)
                        self.onChangeHandler?((self.state as! StateforText).getStateForListener())
                    }
                    self.updateMenuView()
                })
                updatedMenuChildren.append(action)
            }
        }

        dropdownButton.menu = UIMenu(options: .displayInline, children: updatedMenuChildren)
    }

    override func validate() -> SkyflowValidationError {
        let str = actualValue
        if self.errorTriggered {
            return self.errorMessage.text!
        }
        return SkyflowValidator.validate(input: str, rules: validationRules)
    }
    
    func validateCustomRules() -> SkyflowValidationError {
        let str = actualValue
        if self.errorTriggered {
            return ""
        }
        return SkyflowValidator.validate(input: str, rules: userValidationRules)
    }
    
    internal func isValid() -> Bool {
        let state = self.state.getState()
        if (state["isRequired"] as! Bool) && (state["isEmpty"] as! Bool || self.actualValue.isEmpty) {
            return false
        }
        if !(state["isValid"] as! Bool) {
            return false
        }
        
        return true
    }
    
    public func on(eventName: EventName, handler: @escaping ([String: Any]) -> Void) {
        switch eventName {
        case .CHANGE:
            onChangeHandler = handler
        case .BLUR:
            onBlurHandler = handler
        case .READY:
            onReadyHandler = handler
        case .FOCUS:
            onFocusHandler = handler
        case .SUBMIT:
            break
        }
    }
    
    public override func didMoveToWindow() {
        if self.window != nil {
            onReadyHandler?((self.state as! StateforText).getStateForListener())
        }
    }
    
    public func unmount() {
        self.actualValue = ""
        self.textField.secureText = ""
        self.setupField()
    }
}
extension TextField {
    @discardableResult override public func becomeFirstResponder() -> Bool {
        self.hasBecomeResponder = true
        return textField.becomeFirstResponder()
    }
    
    @discardableResult override public func resignFirstResponder() -> Bool {
        self.hasBecomeResponder = false
        return textField.resignFirstResponder()
    }
    override public var isFirstResponder: Bool {
        return textField.isFirstResponder
    }
    
}

extension TextField {
    internal func updateInputStyle(_ style: Style? = nil) {
        self.textField.translatesAutoresizingMaskIntoConstraints = false
        let fallbackStyle = self.collectInput.inputStyles.base
        self.textField.font = style?.font ?? fallbackStyle?.font ?? .none
        self.textField.textAlignment = style?.textAlignment ?? fallbackStyle?.textAlignment ?? .natural
        self.textField.textColor = style?.textColor ?? fallbackStyle?.textColor ?? .none

        if let shadowLayer = style?.boxShadow ?? fallbackStyle?.boxShadow {
            //To apply Shadow
            self.textField.layer.shadowOpacity = shadowLayer.shadowOpacity
            self.textField.layer.shadowRadius = shadowLayer.shadowRadius
            self.textField.layer.shadowOffset = shadowLayer.shadowOffset
            self.textField.layer.shadowColor = shadowLayer.shadowColor
            
        }
        if style?.placeholderColor != nil || fallbackStyle?.placeholderColor != nil {
            let attributes = [
                NSAttributedString.Key.foregroundColor: style?.placeholderColor ?? fallbackStyle?.placeholderColor,
                    NSAttributedString.Key.font: style?.font ?? fallbackStyle?.font
                ]
            self.textField.attributedPlaceholder = NSAttributedString(string: collectInput.placeholder, attributes: attributes)
        }

        self.textField.backgroundColor = style?.backgroundColor ?? fallbackStyle?.backgroundColor ?? .none

        self.textField.tintColor = style?.cursorColor ?? fallbackStyle?.cursorColor ?? UIColor.black
        var p = style?.padding ?? fallbackStyle?.padding ?? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        if self.fieldType == .CARD_NUMBER, self.options.enableCardIcon, cardIconAlignment == .left {
            p.left = 60
            if (listCardTypes != nil){
                if (listCardTypes!.count >= 2){
                    p.left = 70
                }
            }
        }
        
        if style?.width != nil {
            NSLayoutConstraint.activate ([
                self.textField.widthAnchor.constraint(equalToConstant: (style?.width)!)
            ])
            
        }
        if style?.height != nil {
        self.textField.heightAnchor.constraint(equalToConstant: (style?.height)!).isActive = true
        }
        self.textField.padding = p
        self.textFieldBorderWidth = style?.borderWidth ?? fallbackStyle?.borderWidth ?? 0
        self.textFieldBorderColor = style?.borderColor ?? fallbackStyle?.borderColor ?? .none
        self.textFieldCornerRadius = style?.cornerRadius ?? fallbackStyle?.cornerRadius ?? 0

        // Define constraints for width and height
        if let minWidth = style?.minWidth ?? fallbackStyle?.minWidth {
            let minWidthConstraint = self.textField.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth)
            minWidthConstraint.priority = .required
            NSLayoutConstraint.activate([minWidthConstraint])
        }
        if let minHeight =  style?.minHeight ?? fallbackStyle?.minHeight {
            let minHeightConstraint = self.textField.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
            minHeightConstraint.priority = .required
            NSLayoutConstraint.activate([minHeightConstraint])
        }
        if let maxWidth = style?.maxWidth ?? fallbackStyle?.maxWidth {
            let maxWidthConstraint = self.textField.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth)
            NSLayoutConstraint.activate([maxWidthConstraint])

        }
        if let maxHeight = style?.maxHeight ?? fallbackStyle?.maxHeight {
            let maxHeightConstraint = self.textField.heightAnchor.constraint(lessThanOrEqualToConstant: maxHeight)
            // Activate the constraints
            NSLayoutConstraint.activate([maxHeightConstraint])
        }
    }
    
    internal func updateLabelStyle(_ style: Style? = nil) {
        let fallbackStyle = self.collectInput!.labelStyles.base
        self.textFieldLabel.textColor = style?.textColor ?? fallbackStyle?.textColor ?? .none
        self.textFieldLabel.font = style?.font ?? fallbackStyle?.font ?? .none
        self.textFieldLabel.textAlignment = style?.textAlignment ?? fallbackStyle?.textAlignment ?? .left
        self.textFieldLabel.insets = style?.padding ?? fallbackStyle?.padding ?? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    internal func textFieldDidEndEditing(_ textField: UITextField) {
        self.textField.delegate?.textFieldDidEndEditing?(textField)
    }
    
    
    @objc func  textFieldDidChange(_ textField: UITextField) {
        isDirty = true
        
        updateActualValue()
        
        textFieldValueChanged()
        let state = self.state as! StateforText
        
        onChangeHandler?((self.state as! StateforText).getStateForListener())
        if self.fieldType == .CARD_NUMBER {
            let t = self.textField.secureText!.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
            let card = CardType.forCardNumber(cardNumber: t).instance
            updateImage(name: card.imageName, cardNumber: t)
        }
        setFormatPattern()
        onBeginEditing?()

        if self.options.enableCopy && (self.state.getState()["isValid"] as! Bool && !self.actualValue.isEmpty) {
            copyContainerView.isHidden = false
        } else if self.options.enableCopy {
            self.textField.rightViewMode = .always
            copyContainerView.isHidden = true
            
        }

    }
    
    func updateActualValue() {
        if self.fieldType == .CARD_NUMBER {
            self.actualValue = textField.getSecureRawText ?? ""
        } else {
            self.actualValue = textField.secureText ?? ""
        }
    }


    func updateErrorMessage() {

        var isRequiredCheckFailed = false
        let currentState = state.getState()

        if self.errorTriggered {
            updateInputStyle(collectInput!.inputStyles.invalid)
            errorMessage.alpha = 1.0
        } else if self.hasFocus {
            updateInputStyle(collectInput!.inputStyles.focus)
            errorMessage.alpha = 0.0
        } else if (currentState["isEmpty"] as! Bool || self.actualValue.isEmpty) { // Check if empty
            if currentState["isRequired"] as! Bool { // Check if required
                isRequiredCheckFailed = true // Set the original flag
                updateInputStyle(collectInput!.inputStyles.empty)
                errorMessage.alpha = 1.0 // Show error label
            } else {
                updateInputStyle(collectInput!.inputStyles.complete)
                errorMessage.alpha = 0.0 // Hide error label
            }
        } else if !(currentState["isValid"] as! Bool) { // Not empty, check validity
            updateInputStyle(collectInput!.inputStyles.invalid)
            errorMessage.alpha = 1.0
        } else { // Not empty and valid
            updateInputStyle(collectInput!.inputStyles.complete)
            errorMessage.alpha = 0.0
        }

        // First, check if we should display *any* error text (alpha == 1.0)
        // And also check if an external error wasn't already set (which takes precedence)
        if errorMessage.alpha == 1.0 && !self.errorTriggered {
            if let customError = self.customErrorMessage, !customError.isEmpty {
                // <<< NEW: If custom message exists, use it >>>
                self.errorMessage.text = customError
            } else {
                let label = self.collectInput.label
                if isRequiredCheckFailed { // Use the flag set earlier
                    errorMessage.text = (label != "" ? label : "Field") + " is required"
                } else if currentState["isDefaultRuleFailed"] as! Bool { // Check if default rule failed
                     // Generic message for default rule failure
                     errorMessage.text = "Invalid " + (label != "" ? label : "value")
                } else if currentState["isCustomRuleFailed"] as! Bool { // Check if custom rule failed
                    let validationErrorFromState = currentState["validationError"] as? String
                     // Check if the error from state is a custom string (not a known enum raw value)
                    if validationErrorFromState != nil && SkyflowValidationErrorType(rawValue: validationErrorFromState!) == nil {
                        errorMessage.text = validationErrorFromState! // Use the custom rule's message from state
                    } else {
                        // Fallback if custom rule failed but no specific message in state
                        errorMessage.text = "Validation failed"
                    }
                } else {
                     // Fallback if alpha is 1.0 but no specific reason flagged (should be rare if state is accurate)
                     errorMessage.text = "Invalid Input" // Or keep the previous generic "Invalid value"
                }

            }
        } else if errorMessage.alpha == 0.0 {

            errorMessage.text = ""
        }
        

        onEndEditing?() // Keep original call
    }
}

internal extension TextField {
    
    @objc
    override func initialization() {
        super.initialization()
        buildTextFieldUI()
        addTextFieldObservers()
    }
    
    
    @objc
    func buildTextFieldUI() {
        textField.translatesAutoresizingMaskIntoConstraints = false
        errorMessage.translatesAutoresizingMaskIntoConstraints = false
        textFieldLabel.translatesAutoresizingMaskIntoConstraints = false
        
        errorMessage.alpha = 0.0
        errorMessage.text = "Invalid " + (self.collectInput.label != "" ? self.collectInput.label : "value")
        let text = collectInput.label
        
        var verticalAstrisk = -(collectInput.labelStyles.requiredAstrisk?.padding?.top ?? 0.0 ) + (collectInput.labelStyles.requiredAstrisk?.padding?.bottom ?? 0.0 )
        
        let astriskAttributes: [NSAttributedString.Key: Any]  = [
            .strokeWidth:  -3.0,
            .strokeColor: collectInput.labelStyles.requiredAstrisk?.textColor ?? UIColor.red,
            NSAttributedString.Key.font: collectInput.labelStyles.requiredAstrisk?.font ?? UIFont.boldSystemFont(ofSize: 18.0),
            .baselineOffset:  verticalAstrisk > 0.0 ? verticalAstrisk : 2.0
        ]
        
        var leftAstriskPadding = Double(collectInput.labelStyles.requiredAstrisk?.padding?.left ?? 0.0)
        
        
        leftAstriskPadding = leftAstriskPadding / 2
        
        
        DispatchQueue.main.async {
            let attributedString = NSMutableAttributedString(string:text)
            let asterisk = NSAttributedString(string: " *", attributes: astriskAttributes)
            let space = NSAttributedString(string: " ")
            
            
            while leftAstriskPadding > 0 {
                attributedString.append(space)
                leftAstriskPadding-=1
            }
            
            // Only add asterisk if required AND label text is not empty
            if self.isRequired && !text.isEmpty
            {
                
                attributedString.append(asterisk)
            }
            self.textFieldLabel.attributedText = attributedString;
        }
        stackView.addArrangedSubview(textFieldLabel)
        stackView.addArrangedSubview(textField)
        if contextOptions.interface != .COMPOSABLE_CONTAINER {
            stackView.addArrangedSubview(errorMessage)
        }

        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        
        addSubview(stackView)
        setMainPaddings()
    }
    
    @objc
    func addTextFieldObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(textFieldDidChange), name: UITextField.textDidChangeNotification, object: textField)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusOn))
        textField.addGestureRecognizer(tapGesture)
    }
    
    
    @objc
    override func setMainPaddings() {
        super.setMainPaddings()
        
        let views = ["view": self, "stackView": stackView]

        horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(0)-[stackView]-\(0)-|",
                                                               options: .alignAllCenterY,
                                                               metrics: nil,
                                                               views: views)
        NSLayoutConstraint.activate(horizontalConstraints)

        verticalConstraint = NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(0)-[stackView]-\(0)-|",
                                                            options: .alignAllCenterX,
                                                            metrics: nil,
                                                            views: views)
        NSLayoutConstraint.activate(verticalConstraint)
    }
    
    @objc
    func textFieldValueChanged() {
    }
    
    @objc
    func focusOn() {
        textField.becomeFirstResponder()
        onFocusIsTrue?()
        textFieldValueChanged()
        
    }
}

extension TextField {
    public func setError(_ error: String) {
        self.errorTriggered = true
        self.errorMessage.text = error
        updateErrorMessage()
    }
    
    public func resetError() {
        self.errorMessage.text = ""
        self.errorTriggered = false
        updateErrorMessage()
    }
    
    public func getID() -> String {
        return uuid;
    }
}
