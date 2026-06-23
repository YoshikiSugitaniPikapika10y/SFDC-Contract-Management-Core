const PANEL_WIDTH = '70vw';
const PANEL_HEIGHT = '70vh';

function isModalContainer(element) {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) {
        return false;
    }

    const classList = element.classList;
    const tagName = element.tagName ? element.tagName.toLowerCase() : '';

    return (
        classList.contains('slds-modal__container') ||
        classList.contains('uiPanel') ||
        classList.contains('panel') ||
        tagName === 'runtime_platform_actions-quick-action-panel'
    );
}

function findModalContainer(host) {
    let node = host;

    for (let depth = 0; depth < 40 && node; depth++) {
        if (isModalContainer(node)) {
            return node;
        }
        node = node.parentNode || node.host;
    }

    const containers = document.querySelectorAll('.slds-modal__container');
    for (let i = 0; i < containers.length; i++) {
        if (containers[i].contains(host)) {
            return containers[i];
        }
    }

    return null;
}

function resetContainerPosition(container) {
    container.style.setProperty('position', 'relative', 'important');
    container.style.setProperty('top', 'auto', 'important');
    container.style.setProperty('left', 'auto', 'important');
    container.style.setProperty('right', 'auto', 'important');
    container.style.setProperty('bottom', 'auto', 'important');
    container.style.setProperty('transform', 'none', 'important');
    container.style.setProperty('margin', 'auto', 'important');
}

function applyPanelLayout(container) {
    container.style.setProperty('width', PANEL_WIDTH, 'important');
    container.style.setProperty('max-width', PANEL_WIDTH, 'important');
    container.style.setProperty('min-width', PANEL_WIDTH, 'important');
    container.style.setProperty('height', PANEL_HEIGHT, 'important');
    container.style.setProperty('max-height', PANEL_HEIGHT, 'important');
    container.style.setProperty('min-height', PANEL_HEIGHT, 'important');
    resetContainerPosition(container);

    const modal = container.closest('.slds-modal');
    if (modal) {
        modal.style.setProperty('display', 'flex', 'important');
        modal.style.setProperty('align-items', 'center', 'important');
        modal.style.setProperty('justify-content', 'center', 'important');
        modal.style.setProperty('width', '100%', 'important');
        modal.style.setProperty('height', '100%', 'important');
        modal.style.setProperty('top', '0', 'important');
        modal.style.setProperty('left', '0', 'important');
        modal.style.setProperty('right', '0', 'important');
        modal.style.setProperty('bottom', '0', 'important');
        modal.style.setProperty('transform', 'none', 'important');
        modal.style.setProperty('padding', '0', 'important');
    }

    const modalContent =
        container.querySelector('.slds-modal__content') ||
        container.closest('.slds-modal__content');
    if (modalContent) {
        modalContent.style.setProperty('height', '100%', 'important');
        modalContent.style.setProperty('max-height', '100%', 'important');
        modalContent.style.setProperty('overflow', 'hidden', 'important');
    }
}

export function resizeQuickActionPanel(component) {
    if (typeof window === 'undefined' || !component?.template?.host) {
        return;
    }

    const host = component.template.host;
    const run = () => {
        const container = findModalContainer(host);
        if (container) {
            applyPanelLayout(container);
        }
    };

    requestAnimationFrame(run);
    setTimeout(run, 0);
    setTimeout(run, 100);
    setTimeout(run, 300);
}
