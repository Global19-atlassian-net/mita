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
package org.eclipse.mita.base

import com.google.inject.Binder
import com.google.inject.name.Names
import org.eclipse.mita.base.expressions.terminals.ExpressionsValueConverterService
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.scoping.LibraryProviderImpl
import org.eclipse.mita.base.scoping.MitaContainerManager
import org.eclipse.mita.base.scoping.MitaResourceSetBasedAllContainersState
import org.eclipse.mita.base.scoping.MitaTypeSystem
import org.eclipse.mita.base.scoping.TypesGlobalScopeProvider
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.BaseSymbolFactory
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.ISymbolFactory
import org.eclipse.xtext.conversion.IValueConverterService
import org.eclipse.xtext.linking.lazy.LazyURIEncoder
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.scoping.IGlobalScopeProvider

class TypeDslRuntimeModule extends AbstractTypeDslRuntimeModule {

	override configure(Binder binder) {
		super.configure(binder);
		binder.bind(ITypeSystem).toInstance(MitaTypeSystem.getInstance());
		binder.bind(IConstraintFactory).to(BaseConstraintFactory);
		binder.bind(ISymbolFactory).to(BaseSymbolFactory);
	}
	
	def Class<? extends ILibraryProvider> bindILibraryProvider() {
		return LibraryProviderImpl
	}

	override Class<? extends IGlobalScopeProvider> bindIGlobalScopeProvider() {
		return TypesGlobalScopeProvider
	}
	
	override Class<? extends IValueConverterService> bindIValueConverterService() {
		return ExpressionsValueConverterService
	}
	
	override Class<? extends IContainer.Manager> bindIContainer$Manager() {
		return MitaContainerManager;
	}
	
	override bindIAllContainersState$Provider() {
		return MitaResourceSetBasedAllContainersState.Provider;
	}
	
	override configureUseIndexFragmentsForLazyLinking(Binder binder) {
		binder.bind(boolean).annotatedWith(Names.named(LazyURIEncoder.USE_INDEXED_FRAGMENTS_BINDING)).toInstance(false);
	}
}
