// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Redux
import ToolbarKit

class ToolbarMiddleware: FeatureFlaggable {
    private let profile: Profile
    private let manager: ToolbarManager
    private let logger: Logger

    init(profile: Profile = AppContainer.shared.resolve(),
         manager: ToolbarManager = DefaultToolbarManager(),
         logger: Logger = DefaultLogger.shared) {
        self.profile = profile
        self.manager = manager
        self.logger = logger
    }

    lazy var toolbarProvider: Middleware<AppState> = { state, action in
        if let action = action as? GeneralBrowserMiddlewareAction {
            self.resolveGeneralBrowserMiddlewareActions(action: action, state: state)
        } else if let action = action as? ToolbarMiddlewareAction {
            self.resolveToolbarMiddlewareActions(action: action, state: state)
        }
    }

    private func resolveGeneralBrowserMiddlewareActions(action: GeneralBrowserMiddlewareAction, state: AppState) {
        let uuid = action.windowUUID

        switch action.actionType {
        case GeneralBrowserMiddlewareActionType.browserDidLoad:
            let addressToolbarModel = loadInitialAddressToolbarState(state: state, windowUUID: action.windowUUID)
            let navigationToolbarModel = loadInitialNavigationToolbarState(state: state, windowUUID: action.windowUUID)

            let action = ToolbarAction(addressToolbarModel: addressToolbarModel,
                                       navigationToolbarModel: navigationToolbarModel,
                                       windowUUID: uuid,
                                       actionType: ToolbarActionType.didLoadToolbars)
            store.dispatch(action)

        default:
            break
        }
    }

    private func resolveToolbarMiddlewareActions(action: ToolbarMiddlewareAction, state: AppState) {
        switch action.actionType {
        case ToolbarMiddlewareActionType.didTapButton:
            resolveToolbarMiddlewareButtonTapActions(action: action, state: state)

        default:
            break
        }
    }

    private func resolveToolbarMiddlewareButtonTapActions(action: ToolbarMiddlewareAction, state: AppState) {
        guard let buttonType = action.buttonType, let gestureType = action.gestureType else { return }

        let uuid = action.windowUUID
        switch gestureType {
        case .tap: handleToolbarButtonTapActions(actionType: buttonType, windowUUID: uuid)
        case .longPress: handleToolbarButtonLongPressActions(actionType: buttonType, windowUUID: uuid)
        }
    }

    private func loadInitialAddressToolbarState(state: AppState, windowUUID: UUID) -> AddressToolbarModel {
        let displayTopBorder = shouldDisplayAddressToolbarBorder(borderPosition: .top,
                                                                 state: state,
                                                                 windowUUID: windowUUID)
        let displayBottomBorder = shouldDisplayAddressToolbarBorder(borderPosition: .bottom,
                                                                    state: state,
                                                                    windowUUID: windowUUID)

        return AddressToolbarModel(navigationActions: [ToolbarActionState](),
                                   pageActions: loadAddressToolbarPageElements(),
                                   browserActions: [ToolbarActionState](),
                                   displayTopBorder: displayTopBorder,
                                   displayBottomBorder: displayBottomBorder,
                                   url: nil)
    }

    private func loadAddressToolbarPageElements() -> [ToolbarActionState] {
        var pageActions = [ToolbarActionState]()
        pageActions.append(ToolbarActionState(
            actionType: .qrCode,
            iconName: StandardImageIdentifiers.Large.qrCode,
            isEnabled: true,
            a11yLabel: .QRCode.ToolbarButtonA11yLabel,
            a11yId: AccessibilityIdentifiers.Browser.ToolbarButtons.qrCode))
        return pageActions
    }

    private func loadInitialNavigationToolbarState(state: AppState, windowUUID: UUID) -> NavigationToolbarModel {
        let actions = loadNavigationToolbarElements()
        let displayBorder = shouldDisplayNavigationToolbarBorder(state: state, windowUUID: windowUUID)
        return NavigationToolbarModel(actions: actions, displayBorder: displayBorder)
    }

    private func loadNavigationToolbarElements() -> [ToolbarActionState] {
        var elements = [ToolbarActionState]()
        elements.append(ToolbarActionState(actionType: .back,
                                           iconName: StandardImageIdentifiers.Large.back,
                                           isEnabled: false,
                                           a11yLabel: .TabToolbarBackAccessibilityLabel,
                                           a11yId: AccessibilityIdentifiers.Toolbar.backButton))
        elements.append(ToolbarActionState(actionType: .forward,
                                           iconName: StandardImageIdentifiers.Large.forward,
                                           isEnabled: false,
                                           a11yLabel: .TabToolbarForwardAccessibilityLabel,
                                           a11yId: AccessibilityIdentifiers.Toolbar.forwardButton))
        elements.append(ToolbarActionState(actionType: .home,
                                           iconName: StandardImageIdentifiers.Large.home,
                                           isEnabled: true,
                                           a11yLabel: .TabToolbarHomeAccessibilityLabel,
                                           a11yId: AccessibilityIdentifiers.Toolbar.homeButton))
        elements.append(ToolbarActionState(actionType: .tabs,
                                           iconName: StandardImageIdentifiers.Large.tab,
                                           numberOfTabs: 1,
                                           isEnabled: true,
                                           a11yLabel: .TabsButtonShowTabsAccessibilityLabel,
                                           a11yId: AccessibilityIdentifiers.Toolbar.tabsButton))
        elements.append(ToolbarActionState(actionType: .menu,
                                           iconName: StandardImageIdentifiers.Large.appMenu,
                                           isEnabled: true,
                                           a11yLabel: .AppMenu.Toolbar.MenuButtonAccessibilityLabel,
                                           a11yId: AccessibilityIdentifiers.Toolbar.settingsMenuButton))
        return elements
    }

    private func shouldDisplayAddressToolbarBorder(borderPosition: AddressToolbarBorderPosition,
                                                   isPrivate: Bool = false,
                                                   scrollY: CGFloat = 0,
                                                   state: AppState,
                                                   windowUUID: WindowUUID) -> Bool {
        guard let toolbarState = state.screenState(ToolbarState.self,
                                                   for: .toolbar,
                                                   window: windowUUID) else { return false }
        return manager.shouldDisplayAddressBorder(borderPosition: borderPosition,
                                                  toolbarPosition: toolbarState.toolbarPosition,
                                                  isPrivate: isPrivate,
                                                  scrollY: scrollY)
    }

    private func shouldDisplayNavigationToolbarBorder(state: AppState, windowUUID: WindowUUID) -> Bool {
        guard let toolbarState = state.screenState(ToolbarState.self,
                                                   for: .toolbar,
                                                   window: windowUUID) else { return false }
        return manager.shouldDisplayNavigationBorder(toolbarPosition: toolbarState.toolbarPosition)
    }

    private func handleToolbarButtonTapActions(actionType: ToolbarActionState.ActionType, windowUUID: WindowUUID) {
        switch actionType {
        case .home:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.goToHomepage)
            store.dispatch(action)
        case .qrCode:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.showQRcodeReader)
            store.dispatch(action)

        case .back:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.navigateBack)
            store.dispatch(action)

        case .forward:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.navigateForward)
            store.dispatch(action)

        case .tabs:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.showTabTray)
            store.dispatch(action)

        case .trackingProtection:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.showTrackingProtectionDetails)
            store.dispatch(action)
        default:
            break
        }
    }

    private func handleToolbarButtonLongPressActions(actionType: ToolbarActionState.ActionType,
                                                     windowUUID: WindowUUID) {
        switch actionType {
        case .back, .forward:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.showBackForwardList)
            store.dispatch(action)
        case .tabs:
            let action = GeneralBrowserAction(windowUUID: windowUUID,
                                              actionType: GeneralBrowserActionType.showTabsLongPressActions)
            store.dispatch(action)
        default:
            break
        }
    }
}
