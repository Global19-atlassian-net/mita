/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

/*
 * generated by Xtext 2.10.0
 */
package org.eclipse.mita.base.ui

import com.google.inject.Binder
import org.eclipse.mita.base.typesystem.infra.MitaResourceSet
import org.eclipse.mita.base.ui.opener.LibraryURIEditorOpener
import org.eclipse.ui.PlatformUI
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.ui.LanguageSpecific
import org.eclipse.xtext.ui.editor.IURIEditorOpener

/**
 * Use this class to register components to be used within the Eclipse IDE.
 */
@FinalFieldsConstructor
class TypeDslUiModule extends AbstractTypeDslUiModule {

	override configureLanguageSpecificURIEditorOpener(Binder binder) {
		if (PlatformUI.isWorkbenchRunning())
			binder.bind(IURIEditorOpener).annotatedWith(LanguageSpecific).to(LibraryURIEditorOpener);
	}
	
	override configure(Binder binder) {
		super.configure(binder)
		binder.bind(XtextResourceSet).to(MitaResourceSet);
	}
}
